import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import 'hls_local_proxy_server.dart';

/// MVP 阶段的播放源 repository。
///
/// 虽然当前返回 mock URL，但调用方仍必须把它当成真实边界：这里未来会接服务端鉴权、
/// 签名 URL、过期时间和 preload 策略。UI 不能绕过 provider 直接拼 URL，否则
/// locked/unavailable、proxy spike 和 timing trace 都会失去统一入口。
class MockPlayerPlaybackSourceRepository
    implements PlayerPlaybackSourceRepository {
  MockPlayerPlaybackSourceRepository({
    required this.preloadManager,
    this.proxyResolver,
  });

  static const requestDelay = Duration(milliseconds: 40);

  final PlayerPlaybackPreloadManager preloadManager;
  final HlsProxyPlaybackSourceResolver? proxyResolver;
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

    // proxy resolver 只改变播放器实际打开的 playableSource，不改变 remoteUrl。
    // remoteUrl 仍用于业务识别和后续签名/过期策略，避免把本地 spike URL 写回领域层。
    final playableSource = await proxyResolver?.resolvePlayableSource(
      remoteUrl,
    );

    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: playableSource ?? remoteUrl,
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
