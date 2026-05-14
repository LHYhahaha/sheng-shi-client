import 'player_feed.dart';

enum PlaybackCacheStatus { hit, miss, expired, downloading, failed }

class PlaybackCachePolicy {
  const PlaybackCachePolicy({
    required this.allowCache,
    required this.expiresAt,
    required this.cacheKey,
    this.format = 'mp4',
    this.codecHint = 'h264/aac',
  });

  final bool allowCache;
  final DateTime expiresAt;
  final String cacheKey;
  final String format;
  final String codecHint;
}

class PlaybackSource {
  const PlaybackSource({
    required this.itemId,
    required this.remoteUrl,
    required this.playableSource,
    required this.cachePolicy,
    required this.cacheStatus,
  });

  final String itemId;
  final String remoteUrl;
  final String playableSource;
  final PlaybackCachePolicy cachePolicy;
  final PlaybackCacheStatus cacheStatus;

  bool get isCached => cacheStatus == PlaybackCacheStatus.hit;
}

abstract interface class PlayerPlaybackSourceRepository {
  Future<PlaybackSource> resolve(PlayerFeedItem item);

  Future<PlaybackSource> preload(PlayerFeedItem item);
}

abstract interface class PlayerPlaybackCacheManager {
  Future<PlaybackSource?> lookup({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  });

  Future<PlaybackSource> download({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  });

  Future<void> releasePending();
}
