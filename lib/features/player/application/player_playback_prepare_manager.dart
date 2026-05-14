import 'dart:async';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import 'player_session_controller.dart';

enum PreparedPlaybackSessionKind { prepared, retained }

enum _WarmUpResult { firstFrame, timeout, cancelled }

typedef PlayerPrepareTimingLogger =
    void Function(
      String event, {
      String? itemId,
      String? source,
      String? details,
    });

class PreparedPlaybackSession {
  PreparedPlaybackSession({
    required this.itemId,
    required this.source,
    required this.session,
    this.kind = PreparedPlaybackSessionKind.prepared,
    this.isOpened = false,
    this.hasFirstFrame = false,
    this.hasPlaybackAdvanced = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    StreamSubscription<int?>? firstFrameSubscription,
    StreamSubscription<Duration>? positionSubscription,
  }) : _firstFrameSubscription = firstFrameSubscription,
       _positionSubscription = positionSubscription;

  final String itemId;
  final PlaybackSource source;
  final PlayerPlaybackSession session;
  final PreparedPlaybackSessionKind kind;
  bool isOpened;
  bool hasFirstFrame;
  bool hasPlaybackAdvanced;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  StreamSubscription<int?>? _firstFrameSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  Future<void> detachFirstFrameListener() async {
    final subscription = _firstFrameSubscription;
    _firstFrameSubscription = null;
    await subscription?.cancel();
    final positionSubscription = _positionSubscription;
    _positionSubscription = null;
    await positionSubscription?.cancel();
  }

  Future<void> dispose() async {
    await detachFirstFrameListener();
    await session.dispose();
  }
}

class PlayerPlaybackPrepareManager {
  PlayerPlaybackPrepareManager({
    required PlayerPlaybackSession Function() sessionFactory,
    this.maxWindowSessions = 2,
    this.warmUpTimeout = const Duration(milliseconds: 4000),
    this.timingLogger,
  }) : _sessionFactory = sessionFactory;

  final PlayerPlaybackSession Function() _sessionFactory;
  final int maxWindowSessions;
  final Duration warmUpTimeout;
  PlayerPrepareTimingLogger? timingLogger;
  final _window = <String, PreparedPlaybackSession>{};
  final _pendingSessions = <String, PlayerPlaybackSession>{};
  final _warmUpCancels = <String, Completer<void>>{};
  int _generation = 0;

  String? get preparedItemId => _window.keys.lastOrNull;
  List<String> get windowItemIds => List<String>.unmodifiable(_window.keys);

  Future<PreparedPlaybackSession?> prepare({
    required PlayerFeedItem item,
    required PlayerPlaybackSourceRepository sourceRepository,
  }) async {
    if (item.episode.isLocked ||
        item.episode.isUnavailable ||
        item.episode.videoSource == null) {
      return null;
    }

    final existing = _window.remove(item.id);
    if (existing != null) {
      _window[item.id] = existing;
      return existing;
    }

    final generation = ++_generation;
    PlayerPlaybackSession? session;
    StreamSubscription<int?>? widthSubscription;
    StreamSubscription<Duration>? positionSubscription;
    StreamSubscription<bool>? playingSubscription;
    StreamSubscription<bool>? bufferingSubscription;
    try {
      final source = await sourceRepository.resolve(item);
      if (generation != _generation) {
        return null;
      }
      session = _sessionFactory();
      _pendingSessions[item.id] = session;
      var hasFirstFrame = false;
      var hasPlaybackAdvanced = false;
      final firstFrameCompleter = Completer<void>();
      PreparedPlaybackSession? prepared;
      widthSubscription = session.widthStream.listen((width) {
        if (width != null && width > 0) {
          hasFirstFrame = true;
          prepared?.hasFirstFrame = true;
          _log(
            'prepare widthStream received',
            itemId: item.id,
            source: source.playableSource,
            details: 'width=$width',
          );
          if (!firstFrameCompleter.isCompleted) {
            firstFrameCompleter.complete();
          }
        }
      });
      positionSubscription = session.positionStream.listen((position) {
        if (position > Duration.zero) {
          hasPlaybackAdvanced = true;
          prepared?.hasPlaybackAdvanced = true;
          _log(
            'prepare position advanced',
            itemId: item.id,
            source: source.playableSource,
            details: 'positionMs=${position.inMilliseconds}',
          );
        }
      });
      playingSubscription = session.playingStream.listen((isPlaying) {
        _log(
          isPlaying
              ? 'prepare playingStream true'
              : 'prepare playingStream false',
          itemId: item.id,
          source: source.playableSource,
        );
      });
      bufferingSubscription = session.bufferingStream.listen((isBuffering) {
        _log(
          isBuffering ? 'prepare buffering start' : 'prepare buffering end',
          itemId: item.id,
          source: source.playableSource,
        );
      });
      final warmUpCancel = Completer<void>();
      _warmUpCancels[item.id] = warmUpCancel;
      _log(
        'prepare warm-up start',
        itemId: item.id,
        source: source.playableSource,
        details: _details([
          'playMuted=true',
          'timeoutMs=${warmUpTimeout.inMilliseconds}',
        ]),
      );
      await session.setVolume(0);
      _log(
        'prepare open start',
        itemId: item.id,
        source: source.playableSource,
      );
      await session.open(source.playableSource, play: true);
      _log(
        'prepare open completed',
        itemId: item.id,
        source: source.playableSource,
      );
      if (generation != _generation) {
        _pendingSessions.remove(item.id);
        _completeWarmUpCancel(item.id);
        await widthSubscription.cancel();
        await positionSubscription.cancel();
        await playingSubscription.cancel();
        await bufferingSubscription.cancel();
        await session.dispose();
        return null;
      }
      prepared = PreparedPlaybackSession(
        itemId: item.id,
        source: source,
        session: session,
        isOpened: true,
        hasFirstFrame: hasFirstFrame,
        hasPlaybackAdvanced: hasPlaybackAdvanced,
        firstFrameSubscription: widthSubscription,
        positionSubscription: positionSubscription,
      );
      widthSubscription = null;
      positionSubscription = null;
      _pendingSessions.remove(item.id);
      await _put(prepared);
      await playingSubscription.cancel();
      await bufferingSubscription.cancel();
      playingSubscription = null;
      bufferingSubscription = null;
      unawaited(
        _finishWarmUp(
          itemId: item.id,
          generation: generation,
          firstFrame: firstFrameCompleter.future,
          cancel: warmUpCancel.future,
          session: session,
        ),
      );
      return prepared;
    } catch (_) {
      _pendingSessions.remove(item.id);
      _completeWarmUpCancel(item.id);
      await widthSubscription?.cancel();
      await positionSubscription?.cancel();
      await playingSubscription?.cancel();
      await bufferingSubscription?.cancel();
      if (session != null) {
        await session.dispose();
      }
      return null;
    }
  }

  PreparedPlaybackSession? takeIfMatches(String itemId) {
    final before = _windowItemsText;
    _completeWarmUpCancel(itemId);
    final session = _window.remove(itemId);
    _log(
      'prepare manager take',
      itemId: itemId,
      source: session?.source.playableSource,
      details: _details([
        'hit=${session != null}',
        if (session != null) 'kind=${session.kind.name}',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
    return session;
  }

  Future<void> retainPaused(PreparedPlaybackSession session) async {
    await session.session.pause();
    await _put(session);
  }

  Future<void> releaseItem(
    String itemId, {
    String reason = 'release item',
  }) async {
    final before = _windowItemsText;
    _completeWarmUpCancel(itemId);
    final pending = _pendingSessions.remove(itemId);
    if (pending != null) {
      await pending.dispose();
    }
    final session = _window.remove(itemId);
    if (session != null) {
      await session.dispose();
    }
    _log(
      'prepare manager release item',
      itemId: itemId,
      source: session?.source.playableSource,
      details: _details([
        'kind=${session?.kind.name ?? 'none'}',
        'reason=$reason',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  Future<void> retainOnly(Set<String> itemIds) async {
    final before = _windowItemsText;
    for (final key in List<String>.from(_window.keys)) {
      if (!itemIds.contains(key)) {
        await releaseItem(key, reason: 'retain only');
      }
    }
    _log(
      'prepare manager retain only',
      details: _details([
        'reason=retain only',
        'allowed=${itemIds.join(',')}',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  Future<void> release() async {
    _generation += 1;
    final before = _windowItemsText;
    for (final itemId in List<String>.from(_warmUpCancels.keys)) {
      _completeWarmUpCancel(itemId);
    }
    for (final session in List<PlayerPlaybackSession>.from(
      _pendingSessions.values,
    )) {
      await session.dispose();
    }
    _pendingSessions.clear();
    for (final session in List<PreparedPlaybackSession>.from(_window.values)) {
      await session.dispose();
    }
    _window.clear();
    _log(
      'prepare manager release all',
      details: _details([
        'reason=release all',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  Future<void> _finishWarmUp({
    required String itemId,
    required int generation,
    required Future<void> firstFrame,
    required Future<void> cancel,
    required PlayerPlaybackSession session,
  }) async {
    _WarmUpResult result;
    try {
      result = await Future.any<_WarmUpResult>([
        firstFrame.then((_) => _WarmUpResult.firstFrame),
        Future<void>.delayed(warmUpTimeout).then((_) => _WarmUpResult.timeout),
        cancel.then((_) => _WarmUpResult.cancelled),
      ]);
    } catch (_) {
      result = _WarmUpResult.timeout;
    }

    final prepared = _window[itemId];
    if (result == _WarmUpResult.cancelled ||
        generation != _generation ||
        prepared?.session != session) {
      _log(
        'prepare warm-up cancelled',
        itemId: itemId,
        source: prepared?.source.playableSource,
        details: _details(['reason=cancelled_or_stale']),
      );
      return;
    }

    try {
      if (result == _WarmUpResult.timeout) {
        _log(
          'prepare warm-up timeout',
          itemId: itemId,
          source: prepared?.source.playableSource,
          details: 'timeoutMs=${warmUpTimeout.inMilliseconds}',
        );
      }
      _log(
        'prepare pause called',
        itemId: itemId,
        source: prepared?.source.playableSource,
      );
      await session.pause();
      await session.setVolume(100);
      _log(
        'prepare warm-up end',
        itemId: itemId,
        source: prepared?.source.playableSource,
        details: _details([
          'result=${result.name}',
          'firstFrameReady=${prepared?.hasFirstFrame ?? false}',
        ]),
      );
    } catch (error) {
      _log(
        'prepare warm-up failed',
        itemId: itemId,
        source: prepared?.source.playableSource,
        details: 'error=$error',
      );
    } finally {
      _warmUpCancels.remove(itemId);
    }
  }

  void _completeWarmUpCancel(String itemId) {
    final cancel = _warmUpCancels.remove(itemId);
    if (cancel != null && !cancel.isCompleted) {
      cancel.complete();
    }
  }

  Future<void> _put(PreparedPlaybackSession session) async {
    final before = _windowItemsText;
    final replaced = _window.remove(session.itemId);
    if (replaced != null && replaced.session != session.session) {
      await replaced.dispose();
    }
    _window[session.itemId] = session;
    while (_window.length > maxWindowSessions) {
      final oldestKey = _window.keys.first;
      await releaseItem(oldestKey, reason: 'window overflow');
    }
    _log(
      'prepare manager put',
      itemId: session.itemId,
      source: session.source.playableSource,
      details: _details([
        'kind=${session.kind.name}',
        'reason=put',
        'windowItemsBefore=$before',
        'windowItemsAfter=$_windowItemsText',
      ]),
    );
  }

  void _log(String event, {String? itemId, String? source, String? details}) {
    timingLogger?.call(event, itemId: itemId, source: source, details: details);
  }

  String get _windowItemsText => _window.keys.join(',');

  String _details(List<String> parts) {
    return parts.where((part) => part.isNotEmpty).join(' ');
  }
}

class NoopPlayerPlaybackPrepareManager extends PlayerPlaybackPrepareManager {
  NoopPlayerPlaybackPrepareManager()
    : super(sessionFactory: _NoopPlaybackSession.new);

  @override
  Future<PreparedPlaybackSession?> prepare({
    required PlayerFeedItem item,
    required PlayerPlaybackSourceRepository sourceRepository,
  }) async {
    return null;
  }

  @override
  PreparedPlaybackSession? takeIfMatches(String itemId) => null;

  @override
  Future<void> retainPaused(PreparedPlaybackSession session) async {
    await session.session.pause();
  }

  @override
  Future<void> releaseItem(
    String itemId, {
    String reason = 'release item',
  }) async {}

  @override
  Future<void> retainOnly(Set<String> itemIds) async {}

  @override
  Future<void> release() async {}
}

class _NoopPlaybackSession implements PlayerPlaybackSession {
  @override
  Null get videoController => null;

  @override
  Stream<bool> get bufferingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferedPositionStream => const Stream<Duration>.empty();

  @override
  Stream<double> get rateStream => const Stream<double>.empty();

  @override
  Stream<int?> get widthStream => const Stream<int?>.empty();

  @override
  Stream<String> get errorStream => const Stream<String>.empty();

  @override
  Future<void> open(String source, {bool play = true}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}
