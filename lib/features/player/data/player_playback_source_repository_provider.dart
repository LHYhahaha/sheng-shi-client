import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/player_playback_source.dart';
import 'hls_playlist_preloader.dart';
import 'hls_local_proxy_server.dart';
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

/// local HLS proxy spike 的配置入口。
///
/// 它只用于诊断 media_kit 是否能从本地代理获益，默认必须关闭。该开关不应作为普通
/// 缓存策略暴露给 UI，也不能替代服务端/CDN 的 HLS 优化。
final hlsLocalProxyConfigProvider = Provider<HlsLocalProxyConfig>((ref) {
  // local proxy 仍是 spike，默认关闭。它会在本机起 HTTP server 并重写 HLS URL，
  // 对 CORS、ATS/网络安全、后台生命周期和缓存一致性都有额外风险；没有真机验证前
  // 只能通过编译期开关显式打开。
  const enabled = bool.fromEnvironment('PLAYER_HLS_LOCAL_PROXY_SPIKE');
  return const HlsLocalProxyConfig(enabled: enabled);
});

final hlsLocalProxyServerProvider = Provider<HlsLocalProxyServer>((ref) {
  final config = ref.watch(hlsLocalProxyConfigProvider);
  final server = HlsLocalProxyServer(timeout: config.timeout);
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
    timeout: config.effectivePreloadTimeout,
    maxPreheatBytes: config.effectiveMaxPreloadBytes,
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
        );
      }
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerStartupPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });
