import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/user_info_store.dart';
import '../../../core/logging/app_log.dart' as developer;
import '../data/shared_preferences_daily_effective_watch_repository.dart';
import '../domain/daily_effective_watch.dart';

final dailyEffectiveWatchClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final dailyEffectiveWatchControllerProvider =
    NotifierProvider<DailyEffectiveWatchController, DailyEffectiveWatchState>(
      DailyEffectiveWatchController.new,
    );

class DailyEffectiveWatchState {
  const DailyEffectiveWatchState({
    required this.dayKey,
    this.userId,
    this.snapshot,
  });
  final String? userId;
  final String dayKey;
  final DailyEffectiveWatchSnapshot? snapshot;
  bool get ready => snapshot != null;
  int get totalEffectiveMs => snapshot?.totalEffectiveMs ?? 0;
  int get totalEffectiveSeconds => snapshot?.totalEffectiveSeconds ?? 0;
}

/// Application-scoped cache. All loads, credits and writes share one queue so
/// delayed IO cannot overwrite newer snapshots or mix accounts.
class DailyEffectiveWatchController extends Notifier<DailyEffectiveWatchState> {
  final _accumulator = EffectiveWatchAccumulator();
  final _clock = Stopwatch()..start();
  final _snapshots = <(String, String), DailyEffectiveWatchSnapshot>{};
  final _dirty = <(String, String)>{};
  Future<void> _queue = Future.value();
  int _pending = 0;
  String? _userId;
  late DateTime Function() _now;
  late DailyEffectiveWatchRepository _repository;
  Timer? _flushTimer;
  Timer? _dayTimer;
  bool _closed = false;

  @override
  DailyEffectiveWatchState build() {
    _now = ref.read(dailyEffectiveWatchClockProvider);
    _repository = ref.read(dailyEffectiveWatchRepositoryProvider);
    _userId = ref.read(userInfoStoreProvider).userId;
    ref.listen(userInfoStoreProvider.select((value) => value.userId), (
      _,
      user,
    ) {
      _accumulator.stop();
      _userId = user;
      state = DailyEffectiveWatchState(
        userId: user,
        dayKey: IndiaWatchDay.key(_now()),
      );
      unawaited(
        _enqueue(() async {
          await _flushDirty();
          await _refreshCurrent();
        }),
      );
    });
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(flush());
    });
    _scheduleDayBoundary();
    ref.onDispose(() {
      _closed = true;
      _flushTimer?.cancel();
      _dayTimer?.cancel();
      _accumulator.stop();
      // Uses captured repository only; no provider access after disposal.
      unawaited(_enqueue(_flushDirty));
    });
    unawaited(_enqueue(_refreshCurrent));
    return DailyEffectiveWatchState(
      userId: _userId,
      dayKey: IndiaWatchDay.key(_now()),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _pending++;
    _queue = _queue.then((_) async {
      try {
        await operation();
      } catch (error, stackTrace) {
        developer.log(
          'Effective watch cache operation failed',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _pending--;
      }
    });
    return _queue;
  }

  Future<DailyEffectiveWatchSnapshot> _load(String user, String day) async {
    final key = (user, day);
    return _snapshots[key] ??=
        await _repository.read(user, day) ??
        DailyEffectiveWatchSnapshot(userId: user, dayKey: day);
  }

  Future<void> _refreshCurrent() async {
    if (_closed) return;
    final user = _userId;
    final day = IndiaWatchDay.key(_now());
    if (state.userId != user || state.dayKey != day) {
      state = DailyEffectiveWatchState(userId: user, dayKey: day);
    }
    final snapshot = user == null || user.isEmpty
        ? null
        : await _load(user, day);
    if (_closed || user != _userId || day != IndiaWatchDay.key(_now())) return;
    state = DailyEffectiveWatchState(
      userId: user,
      dayKey: day,
      snapshot: snapshot,
    );
  }

  void _scheduleDayBoundary() {
    _dayTimer?.cancel();
    final now = _now();
    _dayTimer = Timer(
      IndiaWatchDay.nextBoundary(now).difference(now.toUtc()),
      () {
        unawaited(_enqueue(_refreshCurrent));
        if (!_closed) _scheduleDayBoundary();
      },
    );
  }

  /// Call only for genuine position events, never UI seek/preview positions.
  void observe({
    required String owner,
    required String userId,
    required String dramaId,
    required String episodeId,
    required int generation,
    required Duration position,
    required double rate,
    Duration? monotonic,
  }) {
    if (_closed ||
        userId.isEmpty ||
        userId != _userId ||
        dramaId.isEmpty ||
        episodeId.isEmpty ||
        _pending >= 512) {
      _accumulator.stop(owner);
      return;
    }
    final segment = _accumulator.observe(
      EffectiveWatchSample(
        owner: owner,
        userId: userId,
        dramaId: dramaId,
        episodeId: episodeId,
        generation: generation,
        positionMs: position.inMilliseconds,
        monotonic: monotonic ?? _clock.elapsed,
        utc: _now().toUtc(),
        rate: rate,
      ),
    );
    if (segment == null) return;
    unawaited(
      _enqueue(() async {
        await _credit(segment);
        await _refreshCurrent();
      }),
    );
  }

  /// Owner-qualified release prevents a hidden old page stopping the new page.
  void stop(String owner) {
    _accumulator.stop(owner);
    unawaited(flush());
  }

  Future<void> _credit(EffectiveWatchSegment segment) async {
    final start = segment.start;
    final end = segment.end;
    final elapsed = (end.monotonic - start.monotonic).inMicroseconds / 1000;
    final boundary = IndiaWatchDay.nextBoundary(start.utc);
    final parts = <(String, int, int, double)>[];
    if (!end.utc.isBefore(boundary)) {
      final ratio =
          boundary.difference(start.utc).inMicroseconds /
          end.utc.difference(start.utc).inMicroseconds;
      final split =
          (start.positionMs + (end.positionMs - start.positionMs) * ratio)
              .round();
      parts.add((
        IndiaWatchDay.key(start.utc),
        start.positionMs,
        split,
        elapsed * ratio,
      ));
      parts.add((
        IndiaWatchDay.key(end.utc),
        split,
        end.positionMs,
        elapsed * (1 - ratio),
      ));
    } else {
      parts.add((
        IndiaWatchDay.key(start.utc),
        start.positionMs,
        end.positionMs,
        elapsed,
      ));
    }
    // Load all partitions before mutating either side of a midnight segment.
    for (final part in parts) {
      await _load(start.userId, part.$1);
    }
    for (final part in parts) {
      final key = (start.userId, part.$1);
      final previous = _snapshots[key]!;
      final next = previous.credit(
        dramaId: start.dramaId,
        episodeId: start.episodeId,
        startMs: part.$2,
        endMs: part.$3,
        elapsedMs: part.$4,
      );
      if (!identical(previous, next)) {
        _snapshots[key] = next;
        _dirty.add(key);
      }
    }
  }

  Future<void> _flushDirty() async {
    for (final key in _dirty.toList()) {
      try {
        await _repository.write(_snapshots[key]!);
        _dirty.remove(key);
      } catch (error, stackTrace) {
        developer.log(
          'Effective watch cache write failed; retained for retry',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final current = (_userId, IndiaWatchDay.key(_now()));
    _snapshots.removeWhere((key, _) => key != current && !_dirty.contains(key));
  }

  /// Also refreshes the date after foreground return or a system clock change.
  Future<void> flush() => _enqueue(() async {
    await _flushDirty();
    await _refreshCurrent();
  });
}
