import 'dart:async';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import 'player_session_controller.dart';

class PreparedPlaybackSession {
  const PreparedPlaybackSession({
    required this.itemId,
    required this.source,
    required this.session,
    required this.hasFirstFrame,
  });

  final String itemId;
  final PlaybackSource source;
  final PlayerPlaybackSession session;
  final bool hasFirstFrame;
}

class PlayerPlaybackPrepareManager {
  PlayerPlaybackPrepareManager({
    required PlayerPlaybackSession Function() sessionFactory,
  }) : _sessionFactory = sessionFactory;

  final PlayerPlaybackSession Function() _sessionFactory;
  PreparedPlaybackSession? _prepared;
  int _generation = 0;

  String? get preparedItemId => _prepared?.itemId;

  Future<PreparedPlaybackSession?> prepare({
    required PlayerFeedItem item,
    required PlayerPlaybackSourceRepository sourceRepository,
  }) async {
    if (item.episode.isLocked ||
        item.episode.isUnavailable ||
        item.episode.videoSource == null) {
      await release();
      return null;
    }

    if (_prepared?.itemId == item.id) {
      return _prepared;
    }

    await release();
    final generation = ++_generation;
    PlayerPlaybackSession? session;
    try {
      final source = await sourceRepository.resolve(item);
      if (generation != _generation) {
        return null;
      }
      session = _sessionFactory();
      var hasFirstFrame = false;
      final widthSubscription = session.widthStream.listen((width) {
        if (width != null && width > 0) {
          hasFirstFrame = true;
        }
      });
      await session.open(source.playableSource, play: false);
      await session.pause();
      await widthSubscription.cancel();
      if (generation != _generation) {
        await session.dispose();
        return null;
      }
      final prepared = PreparedPlaybackSession(
        itemId: item.id,
        source: source,
        session: session,
        hasFirstFrame: hasFirstFrame,
      );
      _prepared = prepared;
      return prepared;
    } catch (_) {
      if (session != null) {
        await session.dispose();
      }
      return null;
    }
  }

  PreparedPlaybackSession? takeIfMatches(String itemId) {
    final prepared = _prepared;
    if (prepared == null || prepared.itemId != itemId) {
      return null;
    }
    _prepared = null;
    return prepared;
  }

  Future<void> release() async {
    _generation += 1;
    final prepared = _prepared;
    _prepared = null;
    if (prepared != null) {
      await prepared.session.dispose();
    }
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
