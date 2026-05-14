import 'player_feed.dart';

enum PlaybackSourceStatus { resolved, preloaded }

class PlaybackSource {
  const PlaybackSource({
    required this.itemId,
    required this.remoteUrl,
    required this.playableSource,
    required this.cacheKey,
    required this.expiresAt,
    required this.codecHint,
    required this.status,
  });

  final String itemId;
  final String remoteUrl;
  final String playableSource;
  final String cacheKey;
  final DateTime expiresAt;
  final String codecHint;
  final PlaybackSourceStatus status;
}

abstract interface class PlayerPlaybackSourceRepository {
  Future<PlaybackSource> resolve(PlayerFeedItem item);

  Future<PlaybackSource> preload(PlayerFeedItem item);
}

abstract interface class PlayerPlaybackPreloadManager {
  Future<void> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
  });

  Future<void> releasePending();
}
