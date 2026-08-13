import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/player_playback_source.dart';
import 'hls_playlist_preloader.dart';
import 'hls_local_proxy_server.dart';
import 'hls_disk_cache_store.dart';
import 'hls_network_request_coordinator.dart';
import 'hls_traffic_gate.dart';
import 'mock_player_playback_source_repository.dart';
import 'player_content_repository_provider.dart';
import 'player_preload_config_provider.dart';
import 'remote/playback_source_remote_data_source.dart';
import 'remote_player_playback_source_repository.dart';

/// 播放器页内部 HLS 预热器。
///
/// 只给 playback scope 使用，生命周期跟 PlayerPlaybackController 的相邻 item 预热绑定。
/// 不要和 startup scope 共用实例，否则 Home 切分类时 releasePending 可能误取消播放器页
/// 的 next/previous 预热。
final hlsPlaylistPreloaderProvider = Provider<HlsPlaylistPreloader>((ref) {
  final config = ref.watch(playerPreloadConfigProvider);
  final preloader = HlsPlaylistPreloader(
    timeout: config.effectivePreloadTimeout,
    maxPreheatBytes: config.effectiveMaxPreloadBytes,
    cacheStore: ref.watch(hlsLocalCacheStoreProvider),
    diskCacheStore: ref.watch(hlsDiskCacheStoreProvider),
    networkCoordinator: ref.watch(hlsNetworkRequestCoordinatorProvider),
  );
  ref.onDispose(preloader.releasePending);
  return preloader;
});

/// 播放页滑动过程使用的 HLS preload manager。
///
/// 这个 provider 只属于播放器页相邻 item 预热，不和首页 startup preload 共用。
/// releasePending 的触发语义跟页面隐藏/切 item 绑定，和首页首屏候选生命周期不同。
final playerPlaybackPreloadManagerProvider =
    Provider<PlayerPlaybackPreloadManager>((ref) {
      return HlsPlayerPlaybackPreloadManager(
        preloader: ref.watch(hlsPlaylistPreloaderProvider),
      );
    });

/// local HLS proxy 的配置入口。
///
/// 当前已解锁 source_url 统一返回 HLS m3u8，因此默认经由本地代理消费 App 私有
/// 分片缓存。若未来接口支持多种媒体封装，应改为根据后端 `stream_format` 按 source
/// 启用；在异常源时可用编译期开关紧急关闭。
final hlsLocalProxyConfigProvider = Provider<HlsLocalProxyConfig>((ref) {
  const disabled = bool.fromEnvironment('PLAYER_DISABLE_HLS_LOCAL_PROXY');
  return HlsLocalProxyConfig(enabled: !disabled);
});

final hlsLocalCacheStoreProvider = Provider<HlsLocalCacheStore>((ref) {
  return HlsLocalCacheStore();
});

final hlsNetworkRequestCoordinatorProvider =
    Provider<HlsNetworkRequestCoordinator>((ref) {
      return HlsNetworkRequestCoordinator();
    });

final hlsTrafficGateProvider = Provider<HlsTrafficGate>((ref) {
  return HlsTrafficGate();
});

final hlsDiskCacheStoreProvider = Provider<HlsDiskCacheStore>((ref) {
  return HlsDiskCacheStore();
});

final hlsLocalProxyServerProvider = Provider<HlsLocalProxyServer>((ref) {
  final config = ref.watch(hlsLocalProxyConfigProvider);
  final server = HlsLocalProxyServer(
    timeout: config.timeout,
    cacheStore: ref.watch(hlsLocalCacheStoreProvider),
    diskCacheStore: ref.watch(hlsDiskCacheStoreProvider),
    networkCoordinator: ref.watch(hlsNetworkRequestCoordinatorProvider),
    trafficGate: ref.watch(hlsTrafficGateProvider),
  );
  ref.onDispose(() {
    unawaited(server.stop());
  });
  return server;
});

final hlsProxyPlaybackSourceResolverProvider =
    Provider<HlsProxyPlaybackSourceResolver>((ref) {
      return HlsProxyPlaybackSourceResolver(
        config: ref.watch(hlsLocalProxyConfigProvider),
        proxyServer: ref.watch(hlsLocalProxyServerProvider),
      );
    });

/// 首页启动预热专用 HLS 预热器。
///
/// startup scope 只处理 Home 首屏“可能点击”的候选资源，不参与正在播放的播放器窗口。
/// 它独立于 playback scope，避免两边的 cancel/release 状态互相误伤。
final startupHlsPlaylistPreloaderProvider = Provider<HlsPlaylistPreloader>((
  ref,
) {
  final config = ref.watch(playerPreloadConfigProvider);
  final preloader = HlsPlaylistPreloader(
    // 首页空闲候选只保留一部，允许它比播放页相邻预热拥有更长的关键分片窗口。
    // 慢源的大首段常超过通用 4 秒预算；到 8 秒前仍只拉 playlist + 首段/续播段，
    // 真正播放或候选切换仍可通过 singleflight 接管已在飞行的请求。
    timeout: config.effectivePreloadTimeout < const Duration(seconds: 8)
        ? const Duration(seconds: 8)
        : config.effectivePreloadTimeout,
    maxPreheatBytes: config.effectiveMaxPreloadBytes,
    cacheStore: ref.watch(hlsLocalCacheStoreProvider),
    diskCacheStore: ref.watch(hlsDiskCacheStoreProvider),
    networkCoordinator: ref.watch(hlsNetworkRequestCoordinatorProvider),
  );
  ref.onDispose(preloader.releasePending);
  return preloader;
});

/// 首页启动预热专用 manager。
///
/// 单独建一套 HLS preloader 是为了隔离 release/cancel：Home 切分类、重试、dispose
/// 只能取消 startup pending，不能打断播放器页当前的相邻 HLS preload。
final playerStartupPreloadManagerProvider =
    Provider<PlayerPlaybackPreloadManager>((ref) {
      return HlsPlayerPlaybackPreloadManager(
        preloader: ref.watch(startupHlsPlaylistPreloaderProvider),
      );
    });

/// 播放器实际播放链路使用的 source repository。
///
/// 这里未来会替换为真实 API + mapper，但上层仍只依赖 PlayerPlaybackSourceRepository。
/// locked/unavailable/null source 的判断也应留在 source/domain 边界，不要让 UI 自行拼 URL。
final playerPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      // UI 层必须通过 provider 读取 repository，而不是自己 new repository/Dio。
      // source resolve 未来会承载鉴权、签名 URL、缓存策略和埋点，入口分散会导致
      // locked/unavailable 边界和 preload release 规则不一致。
      if (ref.watch(useRemotePlayerApiProvider)) {
        return RemotePlayerPlaybackSourceRepository(
          remoteDataSource: PlaybackSourceRemoteDataSource(
            apiClient: ref.watch(apiClientProvider),
          ),
          preloadManager: ref.watch(playerPlaybackPreloadManagerProvider),
          proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
        );
      }
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerPlaybackPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });

/// 首页启动预热使用的 source repository。
///
/// 和 playback repository 使用同一 mock 实现，但依赖 startup preload manager。这个
/// 分离是为了保证 Home 的预热取消不会释放播放器页的 pending preload 或 prepared window。
final playerStartupPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      // startup 使用独立 repository 实例，确保它依赖 startup preload manager。
      // 这不是为了 mock，而是为了把首页预热和播放页预热的资源作用域拆开。
      if (ref.watch(useRemotePlayerApiProvider)) {
        return RemotePlayerPlaybackSourceRepository(
          remoteDataSource: PlaybackSourceRemoteDataSource(
            apiClient: ref.watch(apiClientProvider),
          ),
          preloadManager: ref.watch(playerStartupPreloadManagerProvider),
          proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
        );
      }
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerStartupPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });
