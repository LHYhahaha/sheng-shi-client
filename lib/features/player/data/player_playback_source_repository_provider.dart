import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_playback_source.dart';
import 'hls_playlist_preloader.dart';
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
      );
    });

final playerStartupPlaybackSourceRepositoryProvider =
    Provider<PlayerPlaybackSourceRepository>((ref) {
      return MockPlayerPlaybackSourceRepository(
        preloadManager: ref.watch(playerStartupPreloadManagerProvider),
      );
    });
