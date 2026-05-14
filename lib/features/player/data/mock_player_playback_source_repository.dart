import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';

class MockPlayerPlaybackSourceRepository
    implements PlayerPlaybackSourceRepository {
  MockPlayerPlaybackSourceRepository({required this.cacheManager});

  static const requestDelay = Duration(milliseconds: 40);

  final PlayerPlaybackCacheManager cacheManager;
  bool failNextResolve = false;

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    return _resolve(item, allowDownload: true);
  }

  @override
  Future<PlaybackSource> preload(PlayerFeedItem item) async {
    return _resolve(item, allowDownload: true);
  }

  Future<PlaybackSource> _resolve(
    PlayerFeedItem item, {
    required bool allowDownload,
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

    final policy = PlaybackCachePolicy(
      allowCache: true,
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      cacheKey: 'player:${item.content.id}:${item.episode.id}',
    );
    final cached = await cacheManager.lookup(
      item: item,
      policy: policy,
      remoteUrl: remoteUrl,
    );
    if (cached != null) {
      return cached;
    }
    if (!policy.allowCache || !allowDownload) {
      return PlaybackSource(
        itemId: item.id,
        remoteUrl: remoteUrl,
        playableSource: remoteUrl,
        cachePolicy: policy,
        cacheStatus: PlaybackCacheStatus.miss,
      );
    }
    return cacheManager.download(
      item: item,
      policy: policy,
      remoteUrl: remoteUrl,
    );
  }
}

class MockPlayerPlaybackCacheManager implements PlayerPlaybackCacheManager {
  MockPlayerPlaybackCacheManager({
    this.downloadDelay = const Duration(milliseconds: 80),
  });

  final Duration downloadDelay;
  final _entries = <String, _MockCacheEntry>{};
  var failNextDownload = false;
  var lookupCount = 0;
  var downloadCount = 0;
  var releasePendingCount = 0;

  void seedHit({
    required String cacheKey,
    required String remoteUrl,
    DateTime? expiresAt,
  }) {
    _entries[cacheKey] = _MockCacheEntry(
      remoteUrl: remoteUrl,
      localSource: remoteUrl,
      expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
    );
  }

  void seedExpired({required String cacheKey, required String remoteUrl}) {
    _entries[cacheKey] = _MockCacheEntry(
      remoteUrl: remoteUrl,
      localSource: remoteUrl,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    );
  }

  @override
  Future<PlaybackSource?> lookup({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  }) async {
    lookupCount += 1;
    final entry = _entries[policy.cacheKey];
    if (entry == null) {
      return null;
    }
    if (entry.expiresAt.isBefore(DateTime.now())) {
      return null;
    }
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: entry.localSource,
      cachePolicy: policy,
      cacheStatus: PlaybackCacheStatus.hit,
    );
  }

  @override
  Future<PlaybackSource> download({
    required PlayerFeedItem item,
    required PlaybackCachePolicy policy,
    required String remoteUrl,
  }) async {
    downloadCount += 1;
    await Future<void>.delayed(downloadDelay);
    if (failNextDownload) {
      failNextDownload = false;
      throw StateError('Mock playback cache download failed.');
    }
    _entries[policy.cacheKey] = _MockCacheEntry(
      remoteUrl: remoteUrl,
      localSource: remoteUrl,
      expiresAt: policy.expiresAt,
    );
    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: remoteUrl,
      cachePolicy: policy,
      cacheStatus: PlaybackCacheStatus.miss,
    );
  }

  @override
  Future<void> releasePending() async {
    releasePendingCount += 1;
  }
}

class _MockCacheEntry {
  const _MockCacheEntry({
    required this.remoteUrl,
    required this.localSource,
    required this.expiresAt,
  });

  final String remoteUrl;
  final String localSource;
  final DateTime expiresAt;
}
