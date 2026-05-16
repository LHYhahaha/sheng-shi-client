import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/player_performance_policy_provider.dart';
import '../../application/player_playback_controller.dart';
import '../../domain/player_performance_policy.dart';
import '../../application/player_rebuild_diagnostics.dart';
import '../../application/player_viewport_controller.dart';
import '../../domain/player_content.dart';
import 'player_chrome.dart';

abstract final class PlayerTopBarMetrics {
  static const horizontal = 16.0;
  static const top = 8.0;
  static const height = 40.0;
  static const backIconSize = 28.0;
  static const moreIconSize = 24.0;
}

BoxFit videoFitForEpisode(PlayerEpisode episode) {
  final aspectRatio = episode.videoAspectRatio;
  if (aspectRatio == null || aspectRatio <= 0) {
    return BoxFit.cover;
  }
  const verticalAspectRatio = 9 / 16;
  const tolerance = 0.18;
  if ((aspectRatio - verticalAspectRatio).abs() <= tolerance ||
      aspectRatio < 0.72) {
    return BoxFit.cover;
  }
  return BoxFit.contain;
}

class PlayerViewportBuildSnapshot {
  const PlayerViewportBuildSnapshot({
    required this.currentIndex,
    required this.candidateIndex,
    required this.settledIndex,
    required this.settledItemId,
    required this.scrollPhase,
    required this.generation,
  });

  factory PlayerViewportBuildSnapshot.fromState(PlayerViewportState state) {
    return PlayerViewportBuildSnapshot(
      currentIndex: state.currentIndex,
      candidateIndex: state.candidateIndex,
      settledIndex: state.settledIndex,
      settledItemId: state.settledItemId,
      scrollPhase: state.scrollPhase,
      generation: state.generation,
    );
  }

  final int currentIndex;
  final int candidateIndex;
  final int settledIndex;
  final String? settledItemId;
  final PlayerViewportScrollPhase scrollPhase;
  final int generation;

  @override
  bool operator ==(Object other) {
    return other is PlayerViewportBuildSnapshot &&
        other.currentIndex == currentIndex &&
        other.candidateIndex == candidateIndex &&
        other.settledIndex == settledIndex &&
        other.settledItemId == settledItemId &&
        other.scrollPhase == scrollPhase &&
        other.generation == generation;
  }

  @override
  int get hashCode => Object.hash(
    currentIndex,
    candidateIndex,
    settledIndex,
    settledItemId,
    scrollPhase,
    generation,
  );
}

class PlayerViewportSettledSnapshot {
  const PlayerViewportSettledSnapshot({
    required this.index,
    required this.itemId,
    required this.generation,
  });

  factory PlayerViewportSettledSnapshot.fromState(PlayerViewportState state) {
    return PlayerViewportSettledSnapshot(
      index: state.settledIndex,
      itemId: state.settledItemId,
      generation: state.generation,
    );
  }

  final int index;
  final String? itemId;
  final int generation;

  @override
  bool operator ==(Object other) {
    return other is PlayerViewportSettledSnapshot &&
        other.index == index &&
        other.itemId == itemId &&
        other.generation == generation;
  }

  @override
  int get hashCode => Object.hash(index, itemId, generation);
}

class PlayerPlaybackShellSnapshot {
  const PlayerPlaybackShellSnapshot({
    required this.currentItemId,
    required this.currentSource,
    required this.status,
    required this.surfaceLifecycle,
    required this.hasVideoController,
    required this.playbackRate,
  });

  factory PlayerPlaybackShellSnapshot.fromState(PlayerPlaybackState state) {
    return PlayerPlaybackShellSnapshot(
      currentItemId: state.currentItemId,
      currentSource: state.currentSource,
      status: state.status,
      surfaceLifecycle: state.surfaceLifecycle,
      hasVideoController: state.videoController != null,
      playbackRate: state.playbackRate,
    );
  }

  final String? currentItemId;
  final String? currentSource;
  final PlayerPlaybackStatus status;
  final PlayerVideoSurfaceLifecycle surfaceLifecycle;
  final bool hasVideoController;
  final double playbackRate;

  bool get shouldAttachVideoSurface =>
      surfaceLifecycle == PlayerVideoSurfaceLifecycle.attached;

  bool get canTogglePlayback =>
      status == PlayerPlaybackStatus.playing ||
      status == PlayerPlaybackStatus.paused;

  @override
  bool operator ==(Object other) {
    return other is PlayerPlaybackShellSnapshot &&
        other.currentItemId == currentItemId &&
        other.currentSource == currentSource &&
        other.status == status &&
        other.surfaceLifecycle == surfaceLifecycle &&
        other.hasVideoController == hasVideoController &&
        other.playbackRate == playbackRate;
  }

  @override
  int get hashCode => Object.hash(
    currentItemId,
    currentSource,
    status,
    surfaceLifecycle,
    hasVideoController,
    playbackRate,
  );
}

class PlayerPlaybackRenderSnapshot {
  const PlayerPlaybackRenderSnapshot({
    required this.videoController,
    required this.currentItemId,
    required this.currentSource,
    required this.status,
    required this.surfaceLifecycle,
    required this.hasFirstFrame,
    required this.isBuffering,
    required this.isPlaybackAdvancing,
  });

  factory PlayerPlaybackRenderSnapshot.fromState(PlayerPlaybackState state) {
    return PlayerPlaybackRenderSnapshot(
      videoController: state.videoController,
      currentItemId: state.currentItemId,
      currentSource: state.currentSource,
      status: state.status,
      surfaceLifecycle: state.surfaceLifecycle,
      hasFirstFrame: state.hasFirstFrame,
      isBuffering: state.isBuffering,
      isPlaybackAdvancing: state.position > Duration.zero,
    );
  }

  final VideoController? videoController;
  final String? currentItemId;
  final String? currentSource;
  final PlayerPlaybackStatus status;
  final PlayerVideoSurfaceLifecycle surfaceLifecycle;
  final bool hasFirstFrame;
  final bool isBuffering;
  final bool isPlaybackAdvancing;

  bool get shouldAttachVideoSurface =>
      surfaceLifecycle == PlayerVideoSurfaceLifecycle.attached;
  bool get canMountVideoSurface =>
      shouldAttachVideoSurface && videoController != null;
  bool get isError => status == PlayerPlaybackStatus.error;
  bool get isOpening => status == PlayerPlaybackStatus.opening;
  bool get isLoading =>
      currentSource != null &&
      !isError &&
      (isOpening || isBuffering || !hasFirstFrame);
  bool get isPlaying => status == PlayerPlaybackStatus.playing;
  bool get canTogglePlayback =>
      status == PlayerPlaybackStatus.playing ||
      status == PlayerPlaybackStatus.paused;

  @override
  bool operator ==(Object other) {
    return other is PlayerPlaybackRenderSnapshot &&
        other.videoController == videoController &&
        other.currentItemId == currentItemId &&
        other.currentSource == currentSource &&
        other.status == status &&
        other.surfaceLifecycle == surfaceLifecycle &&
        other.hasFirstFrame == hasFirstFrame &&
        other.isBuffering == isBuffering &&
        other.isPlaybackAdvancing == isPlaybackAdvancing;
  }

  @override
  int get hashCode => Object.hash(
    videoController,
    currentItemId,
    currentSource,
    status,
    surfaceLifecycle,
    hasFirstFrame,
    isBuffering,
    isPlaybackAdvancing,
  );
}

class PlayerSeekBarSnapshot {
  const PlayerSeekBarSnapshot({
    required this.currentSource,
    required this.status,
    required this.hasFirstFrame,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.isSeeking,
    required this.seekPreviewPosition,
  });

  factory PlayerSeekBarSnapshot.fromState(PlayerPlaybackState state) {
    return PlayerSeekBarSnapshot(
      currentSource: state.currentSource,
      status: state.status,
      hasFirstFrame: state.hasFirstFrame,
      isBuffering: state.isBuffering,
      position: state.position,
      duration: state.duration,
      bufferedPosition: state.bufferedPosition,
      isSeeking: state.isSeeking,
      seekPreviewPosition: state.seekPreviewPosition,
    );
  }

  final String? currentSource;
  final PlayerPlaybackStatus status;
  final bool hasFirstFrame;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool isSeeking;
  final Duration? seekPreviewPosition;

  bool get isError => status == PlayerPlaybackStatus.error;
  bool get isOpening => status == PlayerPlaybackStatus.opening;
  bool get isLoading =>
      currentSource != null &&
      !isError &&
      (isOpening || isBuffering || !hasFirstFrame);
  bool get isSeekAllowed =>
      currentSource != null &&
      duration > Duration.zero &&
      (status == PlayerPlaybackStatus.playing ||
          status == PlayerPlaybackStatus.paused);

  @override
  bool operator ==(Object other) {
    return other is PlayerSeekBarSnapshot &&
        other.currentSource == currentSource &&
        other.status == status &&
        other.hasFirstFrame == hasFirstFrame &&
        other.isBuffering == isBuffering &&
        other.position == position &&
        other.duration == duration &&
        other.bufferedPosition == bufferedPosition &&
        other.isSeeking == isSeeking &&
        other.seekPreviewPosition == seekPreviewPosition;
  }

  @override
  int get hashCode => Object.hash(
    currentSource,
    status,
    hasFirstFrame,
    isBuffering,
    position,
    duration,
    bufferedPosition,
    isSeeking,
    seekPreviewPosition,
  );
}

class ActivePlaybackSurfaceOverlay extends ConsumerStatefulWidget {
  const ActivePlaybackSurfaceOverlay({
    super.key,
    required this.sessionKey,
    required this.itemId,
    required this.currentIndex,
    required this.pagePositionListenable,
    required this.canShowVideo,
    required this.policy,
    required this.isViewportDragging,
    required this.videoFit,
    required this.forYouLayout,
  });

  /// rich 模式拖动时 Video surface 压暗 opacity（仅测试/对照引用）。
  static const richScrollFollowOpacity = 0.88;

  final String sessionKey;
  final String? itemId;
  final int currentIndex;
  final ValueListenable<double> pagePositionListenable;
  final bool canShowVideo;
  final PlayerPerformancePolicy policy;
  final bool isViewportDragging;
  final BoxFit videoFit;
  final bool forYouLayout;

  @override
  ConsumerState<ActivePlaybackSurfaceOverlay> createState() =>
      ActivePlaybackSurfaceOverlayState();
}

class ActivePlaybackSurfaceOverlayState
    extends ConsumerState<ActivePlaybackSurfaceOverlay> {
  VideoController? _mountedController;
  String? _visibleItemId;
  double? _lastLoggedPage;
  double? _lastLoggedTranslateY;

  @override
  void dispose() {
    final controller = _mountedController;
    if (controller != null) {
      PlayerRebuildDiagnostics.recordVideoUnmounted(
        itemId: _visibleItemId ?? widget.itemId ?? 'null',
        controller: controller,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playbackProvider = playerPlaybackControllerProvider(
      widget.sessionKey,
    );
    final snapshot = ref.watch(
      playbackProvider.select(PlayerPlaybackRenderSnapshot.fromState),
    );
    final playbackController = ref.read(playbackProvider.notifier);
    final canRender =
        widget.canShowVideo &&
        snapshot.shouldAttachVideoSurface &&
        widget.itemId != null &&
        snapshot.currentItemId == widget.itemId &&
        snapshot.currentSource != null;
    final controller = canRender && snapshot.canMountVideoSurface
        ? snapshot.videoController
        : null;
    _recordControllerLifecycle(controller, snapshot.currentItemId);

    if (!canRender) {
      _recordOverlayHidden(snapshot);
      return const SizedBox.shrink();
    }

    _recordOverlayShown(snapshot);
    final canShowVideoSurface = !snapshot.isError;
    final showVideoBeforeFirstFrame =
        canShowVideoSurface &&
        !snapshot.hasFirstFrame &&
        (snapshot.status == PlayerPlaybackStatus.playing ||
            snapshot.isPlaybackAdvancing);
    if (showVideoBeforeFirstFrame) {
      playbackController.recordVideoSurfaceShownBeforeFirstFrame(
        itemId: widget.itemId!,
        source: snapshot.currentSource,
      );
    }
    final hideDuringDrag =
        widget.isViewportDragging &&
        !widget.policy.allowVideoSurfaceFollowDuringDrag;
    if (hideDuringDrag) {
      _recordOverlayHidden(snapshot);
      return const SizedBox.shrink();
    }

    final showVideo =
        canShowVideoSurface &&
        (snapshot.hasFirstFrame || showVideoBeforeFirstFrame);
    final dimDuringDrag =
        widget.isViewportDragging &&
        widget.policy.allowVideoSurfaceOpacityAnimationDuringDrag;
    final surfaceOpacity = showVideo
        ? (dimDuringDrag ? widget.policy.videoSurfaceDimOpacityDuringDrag : 1.0)
        : 0.0;
    final mediaQuery = MediaQuery.of(context);
    final bottomFrameHeight = widget.forYouLayout
        ? mediaQuery.padding.bottom
        : mediaQuery.padding.bottom + 79;

    final videoChild = controller == null
        ? const SizedBox.shrink()
        : Video(
            key: const ValueKey('active_playback_video_surface'),
            controller: controller,
            controls: NoVideoControls,
            fit: widget.videoFit,
          );

    Widget buildOpacityChild(Widget child) {
      final useAnimated =
          widget.policy.allowVideoSurfaceOpacityAnimationDuringDrag ||
          widget.policy.allowVideoSurfaceOpacityAnimationOnSettle;
      if (!useAnimated) {
        return Opacity(
          key: const ValueKey('active_playback_surface_opacity'),
          opacity: surfaceOpacity,
          child: child,
        );
      }
      return AnimatedOpacity(
        key: const ValueKey('active_playback_surface_opacity'),
        opacity: surfaceOpacity,
        duration: dimDuringDrag
            ? Duration.zero
            : const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      );
    }

    final opacityChild = buildOpacityChild(videoChild);

    if (!widget.policy.allowVideoSurfaceFollowDuringDrag) {
      return Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: bottomFrameHeight,
        child: IgnorePointer(child: opacityChild),
      );
    }

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: bottomFrameHeight,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: widget.pagePositionListenable,
          builder: (context, page, child) {
            final viewportHeight = MediaQuery.sizeOf(context).height;
            final translateY = (widget.currentIndex - page) * viewportHeight;
            _recordOverlayTranslated(
              page: page,
              translateY: translateY,
              viewportHeight: viewportHeight,
            );
            return Transform.translate(
              key: const ValueKey('active_playback_surface_follow_scroll'),
              offset: Offset(0, translateY),
              child: child,
            );
          },
          child: opacityChild,
        ),
      ),
    );
  }

  void _recordControllerLifecycle(
    VideoController? controller,
    String? currentItemId,
  ) {
    if (controller == _mountedController) {
      return;
    }
    final previous = _mountedController;
    if (previous != null && controller != null) {
      PlayerRebuildDiagnostics.recordVideoControllerReplaced(
        itemId: currentItemId ?? widget.itemId ?? 'null',
        previous: previous,
        next: controller,
      );
    } else if (previous == null && controller != null) {
      PlayerRebuildDiagnostics.recordVideoMounted(
        itemId: currentItemId ?? widget.itemId ?? 'null',
        controller: controller,
      );
    } else if (previous != null && controller == null) {
      PlayerRebuildDiagnostics.recordVideoUnmounted(
        itemId: _visibleItemId ?? widget.itemId ?? 'null',
        controller: previous,
      );
    }
    _mountedController = controller;
  }

  void _recordOverlayShown(PlayerPlaybackRenderSnapshot snapshot) {
    if (_visibleItemId == snapshot.currentItemId) {
      return;
    }
    _visibleItemId = snapshot.currentItemId;
    PlayerRebuildDiagnostics.recordTiming(
      'ActiveVideoSurface.show',
      itemId: snapshot.currentItemId,
      details: 'status=${snapshot.status.name}',
    );
  }

  void _recordOverlayHidden(PlayerPlaybackRenderSnapshot snapshot) {
    final previous = _visibleItemId;
    if (previous == null) {
      return;
    }
    _visibleItemId = null;
    PlayerRebuildDiagnostics.recordTiming(
      'ActiveVideoSurface.hide',
      itemId: previous,
      details:
          'status=${snapshot.status.name} current=${snapshot.currentItemId ?? 'null'} canShow=${widget.canShowVideo}',
    );
  }

  void _recordOverlayTranslated({
    required double page,
    required double translateY,
    required double viewportHeight,
  }) {
    if (!PlayerRebuildDiagnostics.enabled) {
      return;
    }
    final lastPage = _lastLoggedPage;
    final lastTranslateY = _lastLoggedTranslateY;
    if (lastPage != null &&
        lastTranslateY != null &&
        (lastPage - page).abs() < 0.25 &&
        (lastTranslateY - translateY).abs() < 80) {
      return;
    }
    _lastLoggedPage = page;
    _lastLoggedTranslateY = translateY;
    PlayerRebuildDiagnostics.recordTiming(
      'ActiveVideoSurface.translate',
      itemId: widget.itemId,
      details:
          'currentIndex=${widget.currentIndex} page=${page.toStringAsFixed(3)} translateY=${translateY.toStringAsFixed(1)} viewportHeight=${viewportHeight.toStringAsFixed(1)}',
    );
  }
}

class PlayerPlaybackControlsConsumer extends ConsumerStatefulWidget {
  const PlayerPlaybackControlsConsumer({
    super.key,
    required this.sessionKey,
    required this.itemId,
    required this.onTogglePlay,
    required this.onRetry,
  });

  final String sessionKey;
  final String itemId;
  final VoidCallback onTogglePlay;
  final VoidCallback onRetry;

  @override
  ConsumerState<PlayerPlaybackControlsConsumer> createState() =>
      PlayerPlaybackControlsConsumerState();
}

class PlayerPlaybackControlsConsumerState
    extends ConsumerState<PlayerPlaybackControlsConsumer> {
  bool _showPauseFeedback = false;
  Timer? _feedbackTimer;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      playerPlaybackControllerProvider(
        widget.sessionKey,
      ).select(PlayerPlaybackRenderSnapshot.fromState),
    );
    final canRender =
        snapshot.shouldAttachVideoSurface &&
        snapshot.currentItemId == widget.itemId &&
        snapshot.currentSource != null;

    if (!canRender) {
      return const SizedBox.shrink();
    }

    final showVideoBeforeFirstFrame =
        !snapshot.isError &&
        !snapshot.hasFirstFrame &&
        (snapshot.status == PlayerPlaybackStatus.playing ||
            snapshot.isPlaybackAdvancing);
    final showLoading =
        canRender && (snapshot.isLoading || showVideoBeforeFirstFrame);
    final canTogglePlayback = snapshot.canTogglePlayback;
    final showCenterPlayButton =
        canTogglePlayback &&
        snapshot.status == PlayerPlaybackStatus.paused &&
        snapshot.hasFirstFrame &&
        !snapshot.isBuffering;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showLoading) const PlaybackLoadingOverlay(),
        if (snapshot.isError) PlaybackRetryOverlay(onRetry: widget.onRetry),
        if (canTogglePlayback)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('player_video_tap_layer'),
              behavior: HitTestBehavior.translucent,
              onTap: _handleVideoTap,
            ),
          ),
        if (showCenterPlayButton) CenterPlayButton(onTap: widget.onTogglePlay),
        if (_showPauseFeedback) const PauseFeedbackIcon(),
      ],
    );
  }

  void _handleVideoTap() {
    final snapshot = ref.read(
      playerPlaybackControllerProvider(
        widget.sessionKey,
      ).select(PlayerPlaybackRenderSnapshot.fromState),
    );
    final allowScaleFeedback = ref
        .read(playerPerformancePolicyProvider)
        .allowPlayPauseScaleFeedback;
    if (snapshot.isPlaying) {
      _feedbackTimer?.cancel();
      if (allowScaleFeedback) {
        setState(() => _showPauseFeedback = true);
        _feedbackTimer = Timer(const Duration(milliseconds: 420), () {
          if (mounted) {
            setState(() => _showPauseFeedback = false);
          }
        });
      }
    }
    widget.onTogglePlay();
  }
}

class PlayerSeekBarConsumer extends ConsumerWidget {
  const PlayerSeekBarConsumer({
    super.key,
    required this.sessionKey,
    required this.thumbnailAssetPath,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekCancel,
  });

  final String sessionKey;
  final String thumbnailAssetPath;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final VoidCallback onSeekEnd;
  final VoidCallback onSeekCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      playerPlaybackControllerProvider(
        sessionKey,
      ).select(PlayerSeekBarSnapshot.fromState),
    );
    final showTrackLoading = snapshot.isLoading && !snapshot.isSeeking;
    final canSeek =
        snapshot.isSeekAllowed && !showTrackLoading && !snapshot.isError;
    if (!canSeek && snapshot.duration <= Duration.zero && !showTrackLoading) {
      return const SizedBox.shrink();
    }
    return PlayerSeekBar(
      position: snapshot.position,
      duration: snapshot.duration,
      bufferedPosition: snapshot.bufferedPosition,
      previewPosition: snapshot.seekPreviewPosition,
      thumbnailAssetPath: thumbnailAssetPath,
      isDragging: snapshot.isSeeking,
      showTrackLoading: showTrackLoading,
      enabled: canSeek,
      onDragStart: onSeekStart,
      onDragUpdate: onSeekUpdate,
      onDragEnd: onSeekEnd,
      onDragCancel: onSeekCancel,
    );
  }
}

class PlaybackLoadingOverlay extends StatelessWidget {
  const PlaybackLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

class PlaybackRetryOverlay extends StatelessWidget {
  const PlaybackRetryOverlay({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 38),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.playerFeedLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 18 / 13,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class CenterPlayButton extends StatelessWidget {
  const CenterPlayButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        key: const ValueKey('player_center_play_button'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 46,
          ),
        ),
      ),
    );
  }
}

class PauseFeedbackIcon extends StatelessWidget {
  const PauseFeedbackIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            key: const ValueKey('player_pause_feedback'),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.episodeNumber,
    required this.playbackRate,
    required this.overlayOpacity,
    this.overlayOpacityListenable,
    required this.onBackTap,
    required this.onSpeedTap,
  });

  final int episodeNumber;
  final double playbackRate;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final VoidCallback onBackTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    final listenable = overlayOpacityListenable;
    if (listenable != null) {
      return ValueListenableBuilder<double>(
        valueListenable: listenable,
        builder: (context, value, child) {
          return AnimatedOpacity(
            key: const ValueKey('player_top_bar_opacity'),
            opacity: value,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: child,
          );
        },
        child: RepaintBoundary(
          key: const ValueKey('player_top_bar_repaint_boundary'),
          child: PlayerTopBarContent(
            episodeNumber: episodeNumber,
            playbackRate: playbackRate,
            onBackTap: onBackTap,
            onSpeedTap: onSpeedTap,
          ),
        ),
      );
    }
    return AnimatedOpacity(
      key: const ValueKey('player_top_bar_opacity'),
      opacity: overlayOpacity,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: RepaintBoundary(
        key: const ValueKey('player_top_bar_repaint_boundary'),
        child: PlayerTopBarContent(
          episodeNumber: episodeNumber,
          playbackRate: playbackRate,
          onBackTap: onBackTap,
          onSpeedTap: onSpeedTap,
        ),
      ),
    );
  }
}

class PlayerTopBarContent extends StatelessWidget {
  const PlayerTopBarContent({
    super.key,
    required this.episodeNumber,
    required this.playbackRate,
    required this.onBackTap,
    required this.onSpeedTap,
  });

  final int episodeNumber;
  final double playbackRate;
  final VoidCallback onBackTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PlayerTopBarMetrics.horizontal,
          PlayerTopBarMetrics.top,
          PlayerTopBarMetrics.horizontal,
          0,
        ),
        child: SizedBox(
          key: const ValueKey('player_single_top_bar'),
          height: PlayerTopBarMetrics.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                key: const ValueKey('player_back_button'),
                behavior: HitTestBehavior.opaque,
                onTap: onBackTap,
                child: const SizedBox.square(
                  dimension: PlayerTopBarMetrics.height,
                  child: Center(
                    child: Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: PlayerTopBarMetrics.backIconSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                key: const ValueKey('player_episode_label'),
                'EP.${episodeNumber.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 18 / 14,
                ),
              ),
              const Spacer(),
              GestureDetector(
                key: const ValueKey('player_speed_button'),
                behavior: HitTestBehavior.opaque,
                onTap: onSpeedTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    _formatRate(context, playbackRate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 18 / 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                key: ValueKey('player_more_button'),
                Icons.more_horiz,
                color: Colors.white,
                size: PlayerTopBarMetrics.moreIconSize,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRate(BuildContext context, double rate) {
    if ((rate - 1.0).abs() < 0.01) {
      return context.l10n.playerSpeed;
    }
    return '${rate.toStringAsFixed(1)}x';
  }
}

class PlayerStateMessage extends StatelessWidget {
  const PlayerStateMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 32),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.82),
                fontSize: 14,
                height: 18 / 14,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class UnavailableEpisodeOverlay extends StatelessWidget {
  const UnavailableEpisodeOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.32),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 42),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 18 / 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
