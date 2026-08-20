import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:drama_client/features/player/presentation/widgets/player_playback_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps loading while decoded frame has not rendered to video surface',
    () {
      const state = PlayerPlaybackState(
        videoController: null,
        status: PlayerPlaybackStatus.playing,
        hasFirstFrame: true,
        isBuffering: false,
        preloadedItemIds: <String>[],
        preloadStates: <PlaybackPreloadState>[],
        position: Duration.zero,
        duration: Duration.zero,
        bufferedPosition: Duration.zero,
        isSeeking: false,
        hasEnded: false,
        playbackRate: 1,
        surfaceLifecycle: PlayerVideoSurfaceLifecycle.attached,
        currentItemId: 'episode-1',
        currentSource: 'https://example.com/video.m3u8',
      );

      expect(PlayerPlaybackRenderSnapshot.fromState(state).isLoading, isTrue);
    },
  );
}
