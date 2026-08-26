import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../application/player_performance_policy_provider.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_ui_controller.dart';
import '../../domain/player_seek_preview_config.dart';
import '../../domain/player_performance_policy.dart';
import '../../application/player_rebuild_diagnostics.dart';
import '../../application/player_viewport_controller.dart';
import '../../domain/player_content.dart';
import '../../domain/player_subtitle.dart';
import 'player_chrome.dart';
import 'player_subtitle_overlay.dart';

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
    required this.hasRenderedFirstFrame,
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
      hasRenderedFirstFrame: state.hasRenderedFirstFrame,
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
  final bool hasRenderedFirstFrame;
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
      (isOpening || isBuffering || !hasFirstFrame || !hasRenderedFirstFrame);

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
        other.hasRenderedFirstFrame == hasRenderedFirstFrame &&
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
    hasRenderedFirstFrame,
    isBuffering,
    isPlaybackAdvancing,
  );
}

class PlayerSeekBarSnapshot {
  const PlayerSeekBarSnapshot({
    required this.currentItemId,
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
      currentItemId: state.currentItemId,
      currentSource: state.currentSource,
      status: state.status,
      hasFirstFrame: state.hasFirstFrame,
      isBuffering: state.isBuffering,
      position: state.displayedPosition,
      duration: state.duration,
      bufferedPosition: state.bufferedPosition,
      isSeeking: state.isSeeking,
      seekPreviewPosition: state.seekPreviewPosition,
    );
  }

  final String? currentItemId;
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

  bool get canShowPassiveTrack =>
      currentSource != null &&
      !isError &&
      (isOpening ||
          status == PlayerPlaybackStatus.playing ||
          status == PlayerPlaybackStatus.paused);

  @override
  bool operator ==(Object other) {
    return other is PlayerSeekBarSnapshot &&
        other.currentItemId == currentItemId &&
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
    currentItemId,
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
        !widget.policy.allowVideoSurfaceVisibleDuringDrag;
    if (hideDuringDrag) {
      _recordOverlayHidden(snapshot);
      return const SizedBox.shrink();
    }

    // 修复：即使首帧未到达，也要让 Video widget 可见（opacity > 0），
    // 这样原生 VideoOutput 才会创建，widthStream 才能收到事件。
    // 否则会形成死循环：首帧未到 -> Video 隐藏 -> 原生 surface 不创建 -> 首帧永远到不了
    final showVideo =
        canShowVideoSurface &&
        (snapshot.hasFirstFrame ||
            showVideoBeforeFirstFrame ||
            snapshot.status == PlayerPlaybackStatus.playing ||
            snapshot.status == PlayerPlaybackStatus.opening);
    final dimDuringDrag =
        widget.isViewportDragging &&
        widget.policy.allowVideoSurfaceOpacityAnimationDuringDrag;
    final surfaceOpacity = showVideo
        ? !snapshot.hasRenderedFirstFrame
              ? 0.01
              : (dimDuringDrag
                    ? widget.policy.videoSurfaceDimOpacityDuringDrag
                    : 1.0)
        : 0.0;

    // 调试：打印Video Surface的渲染条件（正式版可移除）
    // developer.log(...);

    final mediaQuery = MediaQuery.of(context);
    final bottomFrameHeight = PlayerChrome.videoViewportBottomInset(
      forYouLayout: widget.forYouLayout,
      bottomInset: mediaQuery.padding.bottom,
    );

    final videoChild = controller == null
        ? const SizedBox.shrink()
        : KeyedSubtree(
            key: const ValueKey('active_playback_video_surface'),
            child: Video(
              // media_kit 的 VideoState 不会在 didUpdateWidget 中重新绑定 controller。
              // session 切换时必须重建 VideoState，否则它仍监听旧 player，并把新 player
              // 解码出的帧丢给已经销毁的 Surface，表现为“进度在走但画面全黑”。
              key: ObjectKey(controller),
              controller: controller,
              controls: NoVideoControls,
              fit: widget.videoFit,
            ),
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

    final surfaceBorderRadius = widget.forYouLayout
        ? const BorderRadius.vertical(bottom: Radius.circular(10))
        : const BorderRadius.vertical(bottom: Radius.circular(16));
    final opacityChild = ClipRRect(
      borderRadius: surfaceBorderRadius,
      child: buildOpacityChild(videoChild),
    );

    if (!widget.policy.allowVideoSurfaceFollowDuringDrag) {
      return Positioned(
        key: const ValueKey('active_playback_surface_static'),
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
    this.useSingleDramaChromeTap = false,
    this.onExitImmersiveChrome,
    this.onSingleDramaUserInteraction,
  });

  final String sessionKey;
  final String itemId;
  final void Function({required bool pauseRequested}) onTogglePlay;
  final VoidCallback onRetry;

  /// 单剧：沉浸态单击仅恢复 default chrome；default 态单击切换播放/暂停。
  final bool useSingleDramaChromeTap;
  final VoidCallback? onExitImmersiveChrome;
  final VoidCallback? onSingleDramaUserInteraction;

  @override
  ConsumerState<PlayerPlaybackControlsConsumer> createState() =>
      PlayerPlaybackControlsConsumerState();
}

class PlayerPlaybackControlsConsumerState
    extends ConsumerState<PlayerPlaybackControlsConsumer> {
  bool _showPauseFeedback = false;
  bool _showPlayFeedback = false;
  Timer? _feedbackTimer;
  Timer? _pendingSingleTap;
  DateTime? _lastTapAt;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _pendingSingleTap?.cancel();
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
        // 字幕在视频画面之上，但需低于播放/暂停反馈图标和中间播放按钮。
        PlayerSubtitleOverlay(sessionKey: widget.sessionKey),
        if (showCenterPlayButton) CenterPlayButton(onTap: _playWithFeedback),
        if (_showPlayFeedback) const PlayFeedbackIcon(),
        if (_showPauseFeedback) const PauseFeedbackIcon(),
      ],
    );
  }

  void _handleVideoTap() {
    if (widget.useSingleDramaChromeTap) {
      _handleSingleDramaVideoTap();
      return;
    }
    _togglePlayWithFeedback();
  }

  void _handleSingleDramaVideoTap() {
    final snapshot = ref.read(
      playerPlaybackControllerProvider(
        widget.sessionKey,
      ).select(PlayerPlaybackRenderSnapshot.fromState),
    );
    if (!snapshot.canTogglePlayback) {
      return;
    }

    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) < const Duration(milliseconds: 320)) {
      _pendingSingleTap?.cancel();
      _pendingSingleTap = null;
      _lastTapAt = null;
      if (snapshot.isPlaying) {
        _togglePlayWithFeedback();
        widget.onSingleDramaUserInteraction?.call();
      }
      return;
    }

    _lastTapAt = now;
    _pendingSingleTap?.cancel();
    _pendingSingleTap = Timer(const Duration(milliseconds: 280), () {
      _pendingSingleTap = null;
      if (!mounted) {
        return;
      }
      final latest = ref.read(
        playerPlaybackControllerProvider(
          widget.sessionKey,
        ).select(PlayerPlaybackRenderSnapshot.fromState),
      );
      if (!latest.canTogglePlayback) {
        return;
      }
      if (latest.isPlaying) {
        final showsChromeOverlays = ref.read(
          playerUiControllerProvider(
            widget.sessionKey,
          ).select((state) => state.showsChromeOverlays),
        );
        if (!showsChromeOverlays) {
          _showTransientFeedback(_PlaybackFeedbackIcon.play);
          widget.onExitImmersiveChrome?.call();
          return;
        }
        _togglePlayWithFeedback();
        widget.onSingleDramaUserInteraction?.call();
        return;
      }
      _playWithFeedback();
      widget.onSingleDramaUserInteraction?.call();
    });
  }

  void _togglePlayWithFeedback() {
    final snapshot = ref.read(
      playerPlaybackControllerProvider(
        widget.sessionKey,
      ).select(PlayerPlaybackRenderSnapshot.fromState),
    );
    if (snapshot.isPlaying) {
      _showTransientFeedback(_PlaybackFeedbackIcon.pause);
    } else if (snapshot.status == PlayerPlaybackStatus.paused) {
      _showTransientFeedback(_PlaybackFeedbackIcon.play);
    }
    widget.onTogglePlay(pauseRequested: snapshot.isPlaying);
  }

  void _playWithFeedback() {
    _showTransientFeedback(_PlaybackFeedbackIcon.play);
    widget.onTogglePlay(pauseRequested: false);
  }

  void _showTransientFeedback(_PlaybackFeedbackIcon icon) {
    final allowScaleFeedback = ref
        .read(playerPerformancePolicyProvider)
        .allowPlayPauseScaleFeedback;
    if (icon == _PlaybackFeedbackIcon.pause && !allowScaleFeedback) {
      return;
    }
    _feedbackTimer?.cancel();
    setState(() {
      _showPlayFeedback = icon == _PlaybackFeedbackIcon.play;
      _showPauseFeedback = icon == _PlaybackFeedbackIcon.pause;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted) {
        setState(() {
          _showPlayFeedback = false;
          _showPauseFeedback = false;
        });
      }
    });
  }
}

enum _PlaybackFeedbackIcon { play, pause }

class PlayerSeekBarConsumer extends ConsumerStatefulWidget {
  const PlayerSeekBarConsumer({
    super.key,
    required this.sessionKey,
    required this.itemId,
    required this.fallbackDuration,
    required this.thumbnailAssetPath,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekCancel,
  });

  final String sessionKey;
  final String itemId;
  final Duration? fallbackDuration;
  final String thumbnailAssetPath;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final VoidCallback onSeekEnd;
  final VoidCallback onSeekCancel;

  @override
  ConsumerState<PlayerSeekBarConsumer> createState() =>
      _PlayerSeekBarConsumerState();
}

class _PlayerSeekBarConsumerState extends ConsumerState<PlayerSeekBarConsumer> {
  String? _lastVisibilityLog;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      playerPlaybackControllerProvider(
        widget.sessionKey,
      ).select(PlayerSeekBarSnapshot.fromState),
    );
    final previewConfig = PlayerSeekPreviewConfig.fromPolicy(
      ref.watch(playerPerformancePolicyProvider),
    );
    final isCurrentPlaybackItem = snapshot.currentItemId == widget.itemId;
    final effectiveDuration = snapshot.duration > Duration.zero
        ? snapshot.duration
        : widget.fallbackDuration ?? Duration.zero;
    final showTrackLoading = snapshot.isLoading && !snapshot.isSeeking;
    final canControlCurrentItem =
        isCurrentPlaybackItem &&
        snapshot.currentSource != null &&
        (snapshot.status == PlayerPlaybackStatus.playing ||
            snapshot.status == PlayerPlaybackStatus.paused);
    final canSeek =
        effectiveDuration > Duration.zero &&
        (canControlCurrentItem || !isCurrentPlaybackItem) &&
        !showTrackLoading &&
        !snapshot.isError;
    final shouldShowShell =
        !snapshot.isError &&
        (isCurrentPlaybackItem || effectiveDuration > Duration.zero);
    _logVisibility(
      visible: shouldShowShell,
      isCurrentPlaybackItem: isCurrentPlaybackItem,
      effectiveDuration: effectiveDuration,
      snapshot: snapshot,
    );
    if (!shouldShowShell) {
      return const SizedBox.shrink();
    }
    final policy = ref.watch(playerPerformancePolicyProvider);
    final trackFadeDuration = policy.allowRichTransitions
        ? const Duration(milliseconds: 150)
        : Duration.zero;
    return PlayerSeekBar(
      position: isCurrentPlaybackItem ? snapshot.position : Duration.zero,
      duration: effectiveDuration,
      bufferedPosition: isCurrentPlaybackItem
          ? snapshot.bufferedPosition
          : Duration.zero,
      previewPosition: isCurrentPlaybackItem
          ? snapshot.seekPreviewPosition
          : null,
      thumbnailAssetPath: widget.thumbnailAssetPath,
      previewConfig: previewConfig,
      isPassiveTrack: effectiveDuration <= Duration.zero,
      trackFadeDuration: trackFadeDuration,
      isDragging: snapshot.isSeeking,
      showTrackLoading: isCurrentPlaybackItem && showTrackLoading,
      enabled: canSeek,
      onDragStart: canControlCurrentItem ? widget.onSeekStart : null,
      onDragUpdate: canControlCurrentItem ? widget.onSeekUpdate : null,
      onDragEnd: canControlCurrentItem ? widget.onSeekEnd : null,
      onDragCancel: canControlCurrentItem ? widget.onSeekCancel : null,
    );
  }

  void _logVisibility({
    required bool visible,
    required bool isCurrentPlaybackItem,
    required Duration effectiveDuration,
    required PlayerSeekBarSnapshot snapshot,
  }) {
    final message = [
      'visible=$visible',
      'item=${widget.itemId}',
      'playbackItem=${snapshot.currentItemId}',
      'current=$isCurrentPlaybackItem',
      'status=${snapshot.status.name}',
      'source=${snapshot.currentSource != null}',
      'durationMs=${effectiveDuration.inMilliseconds}',
      'fallbackMs=${widget.fallbackDuration?.inMilliseconds ?? 0}',
      'loading=${snapshot.isLoading}',
      'error=${snapshot.isError}',
    ].join(' ');
    if (_lastVisibilityLog == message) {
      return;
    }
    _lastVisibilityLog = message;
    debugPrint('[PlayerSeekBar] ${visible ? 'show' : 'hide'}: $message');
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
            AppRetryButton(onPressed: onRetry, label: context.l10n.retry),
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
          padding: EdgeInsets.all(23),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: SvgPicture.asset('assets/images/player/pause.svg'),
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

class PlayFeedbackIcon extends StatelessWidget {
  const PlayFeedbackIcon({super.key});

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
            key: const ValueKey('player_play_feedback'),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: SvgPicture.asset(
              'assets/images/player/play.svg',
              fit: BoxFit.fill,
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
    required this.subtitles,
    required this.episodeSources,
    required this.currentSubtitleLanguage,
    this.isSubtitleSelectionResolved = true,
    this.showSubtitleEntry = true,
    required this.onSubtitleSelected,
    required this.showChromeOverlays,
  });

  final int episodeNumber;
  final double playbackRate;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final VoidCallback onBackTap;
  final VoidCallback onSpeedTap;
  final List<PlayerSubtitle> subtitles;
  final List<PlayerEpisodeSource> episodeSources;
  final String? currentSubtitleLanguage;
  final bool isSubtitleSelectionResolved;

  /// 页面滑动或切集尚未落位时，延后展示字幕入口，避免显示上一集的状态。
  final bool showSubtitleEntry;
  final ValueChanged<String?> onSubtitleSelected;

  /// 是否处于非沉浸模式；进入沉浸模式时用于关闭展开的字幕菜单。
  final bool showChromeOverlays;

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
            subtitles: subtitles,
            episodeSources: episodeSources,
            currentSubtitleLanguage: currentSubtitleLanguage,
            isSubtitleSelectionResolved: isSubtitleSelectionResolved,
            showSubtitleEntry: showSubtitleEntry,
            onSubtitleSelected: onSubtitleSelected,
            showChromeOverlays: showChromeOverlays,
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
          subtitles: subtitles,
          episodeSources: episodeSources,
          currentSubtitleLanguage: currentSubtitleLanguage,
          isSubtitleSelectionResolved: isSubtitleSelectionResolved,
          showSubtitleEntry: showSubtitleEntry,
          onSubtitleSelected: onSubtitleSelected,
          showChromeOverlays: showChromeOverlays,
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
    required this.subtitles,
    required this.episodeSources,
    required this.currentSubtitleLanguage,
    required this.isSubtitleSelectionResolved,
    required this.showSubtitleEntry,
    required this.onSubtitleSelected,
    required this.showChromeOverlays,
  });

  final int episodeNumber;
  final double playbackRate;
  final VoidCallback onBackTap;
  final VoidCallback onSpeedTap;
  final List<PlayerSubtitle> subtitles;
  final List<PlayerEpisodeSource> episodeSources;
  final String? currentSubtitleLanguage;
  final bool isSubtitleSelectionResolved;
  final bool showSubtitleEntry;
  final ValueChanged<String?> onSubtitleSelected;

  /// 是否处于非沉浸模式；进入沉浸模式时用于关闭展开的字幕菜单。
  final bool showChromeOverlays;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                key: const ValueKey('player_back_button'),
                behavior: HitTestBehavior.opaque,
                onTap: onBackTap,
                child: Center(
                  child: Image.asset(
                    "assets/images/common/white_left.png",
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                key: const ValueKey('player_episode_label'),
                context.l10n.myListEpisode(
                  episodeNumber.toString().padLeft(2, '0'),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight(510),
                  fontSize: 14,
                  height: 18 / 14,
                ),
              ),
              const Spacer(),
              if (showSubtitleEntry &&
                  isSubtitleSelectionResolved &&
                  (episodeSources.isNotEmpty
                      ? episodeSources.length > 1
                      : subtitles.isNotEmpty))
                _PlayerSubtitleMenuButton(
                  key: const ValueKey('player_subtitle_button'),
                  subtitles: subtitles,
                  episodeSources: episodeSources,
                  currentSubtitleLanguage: currentSubtitleLanguage,
                  onSubtitleSelected: onSubtitleSelected,
                  showChromeOverlays: showChromeOverlays,
                ),
              // const SizedBox(width: 4),
              // // 倍速按钮
              // GestureDetector(
              //   key: const ValueKey('player_speed_button'),
              //   behavior: HitTestBehavior.opaque,
              //   onTap: onSpeedTap,
              //   child: Padding(
              //     padding: const EdgeInsets.symmetric(
              //       horizontal: 4,
              //       vertical: 6,
              //     ),
              //     child: Text(
              //       _formatRate(context, playbackRate),
              //       style: const TextStyle(
              //         color: Colors.white,
              //         fontSize: 14,
              //         height: 18 / 14,
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSubtitleMenuButton extends StatefulWidget {
  const _PlayerSubtitleMenuButton({
    super.key,
    required this.subtitles,
    required this.episodeSources,
    required this.currentSubtitleLanguage,
    required this.onSubtitleSelected,
    required this.showChromeOverlays,
  });

  final List<PlayerSubtitle> subtitles;
  final List<PlayerEpisodeSource> episodeSources;
  final String? currentSubtitleLanguage;
  final ValueChanged<String?> onSubtitleSelected;

  /// 是否处于非沉浸模式；进入沉浸模式时关闭已展开的字幕菜单。
  final bool showChromeOverlays;

  @override
  State<_PlayerSubtitleMenuButton> createState() =>
      _PlayerSubtitleMenuButtonState();
}

class _PlayerSubtitleMenuButtonState extends State<_PlayerSubtitleMenuButton> {
  bool _isMenuOpen = false;
  final _menuLayerLink = LayerLink();
  OverlayEntry? _menuOverlay;

  @override
  void didUpdateWidget(covariant _PlayerSubtitleMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 进入沉浸模式（chrome 隐藏）时，若字幕菜单仍展开则关闭。
    if (oldWidget.showChromeOverlays &&
        !widget.showChromeOverlays &&
        _isMenuOpen) {
      // 菜单通过 Overlay 展示；进入沉浸模式时立即移除它。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMenuOpen) {
          _closeMenu();
        }
      });
    }
  }

  @override
  void dispose() {
    _removeMenuOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }
    return CompositedTransformTarget(
      link: _menuLayerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentSubtitleLabel(),
                style: TextStyle(
                  color: !_isVisible
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                  fontSize: 14,
                  height: 18 / 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isMenuOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _closedSubtitleValue = '__closed__';
  static const _menuHorizontalPadding = 20.0;
  static const _selectedIndicatorWidth = 24.0;
  static const _menuOptionHeight = 20.0;
  static const _menuOptionGap = 20.0;
  static const _maxVisibleMenuOptions = 3.8;
  static const _menuTextStyle = TextStyle(color: Colors.white, fontSize: 14);

  List<({String label, String value})> get _menuOptions => [
    // 只要存在内嵌字幕视频，语言入口完全由它驱动。外挂字幕仅自动匹配
    // language_code 后显示，不应把外挂独有语言带进菜单。
    if (_showsClosedOption) (label: 'Closed', value: _closedSubtitleValue),
    if (widget.episodeSources.isEmpty)
      ...widget.subtitles.map(
        (subtitle) => (
          label: subtitle.language,
          value: subtitle.languageCode.isNotEmpty
              ? subtitle.languageCode
              : subtitle.language,
        ),
      )
    else
      ...widget.episodeSources.map(
        (source) => (
          label: source.language,
          value: source.languageCode.isNotEmpty
              ? source.languageCode
              : source.language,
        ),
      ),
  ];

  void _toggleMenu() {
    if (_isMenuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final overlay = Overlay.of(context, rootOverlay: true);
    _menuOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeMenu,
            ),
          ),
          CompositedTransformFollower(
            link: _menuLayerLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: _menuWidth(context),
                padding: const EdgeInsets.all(_menuHorizontalPadding),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  height: _menuHeightFor(_menuOptions.length),
                  child: SingleChildScrollView(
                    key: const ValueKey('player_subtitle_menu_scroll'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          var index = 0;
                          index < _menuOptions.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: _menuOptionGap),
                          SizedBox(
                            height: _menuOptionHeight,
                            child: _SubtitleMenuOption(
                              label: _menuOptions[index].label,
                              selected: _isSelected(_menuOptions[index].value),
                              onTap: () =>
                                  _selectMenuOption(_menuOptions[index].value),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_menuOverlay!);
    setState(() => _isMenuOpen = true);
  }

  void _selectMenuOption(String value) {
    _closeMenu();
    widget.onSubtitleSelected(value == _closedSubtitleValue ? null : value);
  }

  void _closeMenu() {
    _removeMenuOverlay();
    if (mounted && _isMenuOpen) {
      setState(() => _isMenuOpen = false);
    }
  }

  void _removeMenuOverlay() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  double _menuWidth(BuildContext context) {
    final resolvedTextStyle = DefaultTextStyle.of(
      context,
    ).style.merge(_menuTextStyle);
    final labels = _menuOptions.map((option) => option.label);
    var widestText = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: resolvedTextStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      widestText = math.max(widestText, painter.width);
    }
    return widestText.ceilToDouble() +
        _menuHorizontalPadding * 2 +
        _selectedIndicatorWidth;
  }

  double _menuHeightFor(int optionCount) {
    final visibleCount = math.min(optionCount, _maxVisibleMenuOptions);
    if (visibleCount == 0) return 0;
    return visibleCount * _menuOptionHeight +
        (visibleCount - 1) * _menuOptionGap;
  }

  String _currentSubtitleLabel() {
    if (_showsClosedOption && widget.currentSubtitleLanguage == null) {
      return 'Subtitle: Closed';
    }
    final current = widget.currentSubtitleLanguage;
    if (current == null) return '';
    for (final option in _menuOptions) {
      if (_isSameLanguageCode(option.value, current)) {
        return option.label;
      }
    }
    return current;
  }

  bool _isSelected(String value) {
    if (value == _closedSubtitleValue) {
      return _showsClosedOption && widget.currentSubtitleLanguage == null;
    }
    final current = widget.currentSubtitleLanguage;
    return current != null && _isSameLanguageCode(current, value);
  }

  bool _isSameLanguageCode(String first, String second) =>
      first.trim().toLowerCase() == second.trim().toLowerCase();

  bool get _showsClosedOption =>
      widget.subtitles.isNotEmpty && widget.episodeSources.isEmpty;

  bool get _isVisible => widget.episodeSources.isNotEmpty
      ? widget.episodeSources.length > 1
      : widget.subtitles.isNotEmpty;
}

class _SubtitleMenuOption extends StatelessWidget {
  const _SubtitleMenuOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _PlayerSubtitleMenuButtonState._menuTextStyle.copyWith(
                color: selected ? AppColors.primary : Colors.white,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
          if (selected)
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
        ],
      ),
    );
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
              AppRetryButton(onPressed: onAction, label: actionLabel!),
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
