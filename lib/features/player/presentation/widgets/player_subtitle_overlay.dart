import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../application/player_playback_controller.dart';
import '../../application/player_viewport_controller.dart';
import '../../domain/player_subtitle.dart';

/// 播放器字幕叠加层。
///
/// 根据 [PlayerPlaybackState.currentSubtitleText] 渲染当前应显示的字幕。
/// 无字幕或文本为空时不渲染。
class PlayerSubtitleOverlay extends ConsumerWidget {
  const PlayerSubtitleOverlay({required this.sessionKey, super.key});

  final String sessionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerPlaybackControllerProvider(sessionKey));
    final viewport = ref.watch(playerViewportControllerProvider(sessionKey));

    final text = state.currentSubtitleText;
    final canShowSubtitle =
        state.currentSource != null &&
        viewport.scrollPhase == PlayerViewportScrollPhase.idle &&
        viewport.settledItemId == state.currentItemId &&
        state.hasFirstFrame &&
        !state.isBuffering &&
        (state.status == PlayerPlaybackStatus.playing ||
            state.status == PlayerPlaybackStatus.paused);
    if (text.isEmpty || !canShowSubtitle) {
      return const SizedBox.shrink();
    }

    final position = state.currentSubtitlePosition;
    return Positioned(
      left: 0,
      right: 0,
      top: switch (position) {
        PlayerSubtitlePosition.top => 100.w,
        PlayerSubtitlePosition.middle => 0,
        PlayerSubtitlePosition.bottom => null,
      },
      bottom: switch (position) {
        PlayerSubtitlePosition.bottom => 160.w,
        PlayerSubtitlePosition.middle => 0,
        PlayerSubtitlePosition.top => null,
      },
      child: IgnorePointer(
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 70.w, vertical: 8.w),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black87,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
