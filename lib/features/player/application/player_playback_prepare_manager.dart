import 'dart:async';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import 'player_session_controller.dart';

enum PreparedPlaybackSessionKind { prepared, retained }

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
    this.hasFirstFrame = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    StreamSubscription<int?>? firstFrameSubscription,
  }) : _firstFrameSubscription = firstFrameSubscription;

  final String itemId;
  final PlaybackSource source;
  final PlayerPlaybackSession session;
  final PreparedPlaybackSessionKind kind;
  bool hasFirstFrame;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  StreamSubscription<int?>? _firstFrameSubscription;

  Future<void> detachFirstFrameListener() async {
    final subscription = _firstFrameSubscription;
    _firstFrameSubscription = null;
    await subscription?.cancel();
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
    this.timingLogger,
  }) : _sessionFactory = sessionFactory;

  final PlayerPlaybackSession Function() _sessionFactory;
  final int maxWindowSessions;
  PlayerPrepareTimingLogger? timingLogger;
  final _window = <String, PreparedPlaybackSession>{};
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
    try {
      final source = await sourceRepository.resolve(item);
      if (generation != _generation) {
        return null;
      }
      session = _sessionFactory();
      var hasFirstFrame = false;
      PreparedPlaybackSession? prepared;
      widthSubscription = session.widthStream.listen((width) {
        if (width != null && width > 0) {
          hasFirstFrame = true;
          prepared?.hasFirstFrame = true;
        }
      });
      await session.open(source.playableSource, play: false);
      await session.pause();
      if (generation != _generation) {
        await widthSubscription.cancel();
        await session.dispose();
        return null;
      }
      prepared = PreparedPlaybackSession(
        itemId: item.id,
        source: source,
        session: session,
        hasFirstFrame: hasFirstFrame,
        firstFrameSubscription: widthSubscription,
      );
      widthSubscription = null;
      await _put(prepared);
      return prepared;
    } catch (_) {
      await widthSubscription?.cancel();
      if (session != null) {
        await session.dispose();
      }
      return null;
    }
  }

  PreparedPlaybackSession? takeIfMatches(String itemId) {
    final before = _windowItemsText;
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
  Future<void> dispose() async {}
}
