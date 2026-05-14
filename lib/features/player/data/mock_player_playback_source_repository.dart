import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';

class MockPlayerPlaybackSourceRepository
    implements PlayerPlaybackSourceRepository {
  MockPlayerPlaybackSourceRepository({required this.preloadManager});

  static const requestDelay = Duration(milliseconds: 40);

  final PlayerPlaybackPreloadManager preloadManager;
  bool failNextResolve = false;

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    return _resolve(item, status: PlaybackSourceStatus.resolved);
  }

  @override
  Future<PlaybackPreloadState> preload(PlayerFeedItem item) async {
    final source = await _resolve(item, status: PlaybackSourceStatus.preloaded);
    return preloadManager.preload(item: item, source: source);
  }

  Future<PlaybackSource> _resolve(
    PlayerFeedItem item, {
    required PlaybackSourceStatus status,
  }) async {
    final remoteUrl = item.episode.videoSource;
    if (remoteUrl == null) {
      throw StateError('Episode has no playable source.');
    }
    await Future<void>.delayed(requestDelay);
    if (failNextResolve) {
      failNextResolve = false;
      throw StateError('Mock playback source resolve failed.');
    }

    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: remoteUrl,
      cacheKey: 'player:${item.content.id}:${item.episode.id}',
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      codecHint: 'hls',
      status: status,
    );
  }
}

class MockPlayerPlaybackPreloadManager implements PlayerPlaybackPreloadManager {
  MockPlayerPlaybackPreloadManager({
    this.preloadDelay = const Duration(milliseconds: 80),
  });

  final Duration preloadDelay;
  final preloadedItemIds = <String>[];
  var failNextPreload = false;
  var preloadCount = 0;
  var releasePendingCount = 0;
  var _generation = 0;

  @override
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
  }) async {
    preloadCount += 1;
    final generation = _generation;
    final startedAt = DateTime.now();
    await Future<void>.delayed(preloadDelay);
    if (generation != _generation) {
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: source.playableSource,
        status: PlaybackPreloadStatus.cancelled,
        startedAt: startedAt,
        completedAt: DateTime.now(),
      );
    }
    if (failNextPreload) {
      failNextPreload = false;
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: source.playableSource,
        status: PlaybackPreloadStatus.failed,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        error: StateError('Mock playback source preload failed.'),
      );
    }
    preloadedItemIds.add(item.id);
    return PlaybackPreloadState(
      itemId: item.id,
      sourceUrl: source.playableSource,
      status: PlaybackPreloadStatus.success,
      startedAt: startedAt,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<void> releasePending() async {
    _generation += 1;
    releasePendingCount += 1;
  }
}
