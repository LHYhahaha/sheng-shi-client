import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_source.dart';
import 'hls_playlist_preloader.dart';
import 'hls_local_proxy_server.dart';
import 'mock_player_playback_source_repository.dart';
import 'player_preload_config_provider.dart';

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

final playerPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      // UI 层必须通过 provider 读取 repository，而不是自己 new repository/Dio。
      // source resolve 未来会承载鉴权、签名 URL、缓存策略和埋点，入口分散会导致
      // locked/unavailable 边界和 preload release 规则不一致。
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerPlaybackPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });

final playerStartupPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      // startup 使用独立 repository 实例，确保它依赖 startup preload manager。
      // 这不是为了 mock，而是为了把首页预热和播放页预热的资源作用域拆开。
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerStartupPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });
