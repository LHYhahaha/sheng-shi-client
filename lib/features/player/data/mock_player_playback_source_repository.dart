import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';

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
  Future<PlaybackSource> preload(PlayerFeedItem item) async {
    final source = await _resolve(item, status: PlaybackSourceStatus.preloaded);
    await preloadManager.preload(item: item, source: source);
    return source;
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

  @override
  Future<void> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
  }) async {
    preloadCount += 1;
    await Future<void>.delayed(preloadDelay);
    if (failNextPreload) {
      failNextPreload = false;
      throw StateError('Mock playback source preload failed.');
    }
    preloadedItemIds.add(item.id);
  }

  @override
  Future<void> releasePending() async {
    releasePendingCount += 1;
  }
}
