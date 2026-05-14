import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_source.dart';
import 'hls_playlist_preloader.dart';
import 'hls_local_proxy_server.dart';
import 'mock_player_playback_source_repository.dart';

final hlsPlaylistPreloaderProvider = Provider<HlsPlaylistPreloader>((ref) {
  final preloader = HlsPlaylistPreloader();
  ref.onDispose(preloader.releasePending);
  return preloader;
});

final playerPlaybackPreloadManagerProvider =
    Provider<PlayerPlaybackPreloadManager>((ref) {
      return HlsPlayerPlaybackPreloadManager(
        preloader: ref.watch(hlsPlaylistPreloaderProvider),
      );
    });

final hlsLocalProxyConfigProvider = Provider<HlsLocalProxyConfig>((ref) {
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
  final preloader = HlsPlaylistPreloader();
  ref.onDispose(preloader.releasePending);
  return preloader;
});

final playerStartupPreloadManagerProvider =
    Provider<PlayerPlaybackPreloadManager>((ref) {
      return HlsPlayerPlaybackPreloadManager(
        preloader: ref.watch(startupHlsPlaylistPreloaderProvider),
      );
    });

final playerPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerPlaybackPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });

final playerStartupPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerStartupPreloadManagerProvider),
        proxyResolver: ref.watch(hlsProxyPlaybackSourceResolverProvider),
      );
    });
