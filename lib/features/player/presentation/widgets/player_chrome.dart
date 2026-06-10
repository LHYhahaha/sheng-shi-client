import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/player_like_count_provider.dart';
import '../../domain/player_content.dart';
import '../../domain/player_performance_policy.dart';
import '../../domain/player_seek_preview_config.dart';

abstract final class _PlayerLayoutMetrics {
  static const forYouActionRailBottom = 160.0;
  static const singleActionRailBottom = 161.0;
  static const forYouWatchNowBottom = 24.0;
  static const forYouMetaGap = 58.0;
  static const singleBottomFrameHeight = 32.0;
  static const singleMetaBottom = 58.0;
  static const singleSeekBarBottom = 10.0;
}

class PlayerChrome extends StatefulWidget {
  const PlayerChrome({
    required this.content,
    required this.isPlaying,
    required this.showCenterPlayButton,
    required this.onTogglePlay,
    required this.onWatchNowTap,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onMoreTap,
    required this.onUnlockTap,
    required this.onLikeTap,
    this.showUnlockButton = false,
    this.unlockLabel,
    this.overlayOpacity = 1.0,
    this.overlayOpacityListenable,
    this.showViewportBackdrop = true,
    this.showLoading = false,
    this.playbackError = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.seekPreviewPosition,
    this.isSeeking = false,
    this.showTrackLoading = false,
    this.canSeek = false,
    this.onSeekStart,
    this.onSeekUpdate,
    this.onSeekEnd,
    this.onSeekCancel,
    this.onRetry,
    this.playbackLayer,
    this.seekBar,
    this.videoFit = BoxFit.cover,
    this.forYouLayout = false,
    this.showChromeOverlays = true,
    this.chromeOverlayFadeDuration = Duration.zero,
    this.isLiked = false,
    this.isLikeLoading = false,
    super.key,
  });

  final PlayerContent content;
  final bool isPlaying;
  final bool showCenterPlayButton;
  final VoidCallback onTogglePlay;
  final VoidCallback onWatchNowTap;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback onUnlockTap;
  final VoidCallback onLikeTap;
  final bool showUnlockButton;
  final String? unlockLabel;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final bool showViewportBackdrop;
  final bool showLoading;
  final bool playbackError;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final Duration? seekPreviewPosition;
  final bool isSeeking;
  final bool showTrackLoading;
  final bool canSeek;
  final VoidCallback? onSeekStart;
  final ValueChanged<Duration>? onSeekUpdate;
  final VoidCallback? onSeekEnd;
  final VoidCallback? onSeekCancel;
  final VoidCallback? onRetry;
  final Widget? playbackLayer;
  final Widget? seekBar;
  final BoxFit videoFit;
  final bool forYouLayout;

  /// 是否显示非必要 chrome（action/meta/渐变等）；false 为沉浸模式。
  final bool showChromeOverlays;

  /// chrome 显隐过渡；stable/ultraStable 应为 [Duration.zero] 或极短。
  final Duration chromeOverlayFadeDuration;

  /// 是否已点赞。
  final bool isLiked;

  /// 是否正在加载点赞状态。
  final bool isLikeLoading;

  @visibleForTesting
  static double videoViewportBottomInset({
    required bool forYouLayout,
    required double bottomInset,
  }) {
    if (forYouLayout) {
      return bottomInset;
    }
    return _PlayerLayoutMetrics.singleBottomFrameHeight + bottomInset;
  }

  @override
  State<PlayerChrome> createState() => _PlayerChromeState();
}

class _PlayerChromeState extends State<PlayerChrome> {
  bool _showPauseFeedback = false;
  Timer? _feedbackTimer;

  PlayerContent get content => widget.content;

  bool get isPlaying => widget.isPlaying;

  bool get showCenterPlayButton => widget.showCenterPlayButton;

  VoidCallback get onTogglePlay => widget.onTogglePlay;

  VoidCallback get onWatchNowTap => widget.onWatchNowTap;

  VoidCallback get onEpisodesTap => widget.onEpisodesTap;

  VoidCallback get onShareTap => widget.onShareTap;

  VoidCallback get onMoreTap => widget.onMoreTap;

  VoidCallback get onUnlockTap => widget.onUnlockTap;

  VoidCallback get onLikeTap => widget.onLikeTap;

  bool get showUnlockButton => widget.showUnlockButton;

  String? get unlockLabel => widget.unlockLabel;

  double get overlayOpacity => widget.overlayOpacity;

  ValueListenable<double>? get overlayOpacityListenable =>
      widget.overlayOpacityListenable;

  bool get showViewportBackdrop => widget.showViewportBackdrop;

  bool get showLoading => widget.showLoading;

  bool get playbackError => widget.playbackError;

  Duration get position => widget.position;

  Duration get duration => widget.duration;

  Duration get bufferedPosition => widget.bufferedPosition;

  Duration? get seekPreviewPosition => widget.seekPreviewPosition;

  bool get isSeeking => widget.isSeeking;

  bool get showTrackLoading => widget.showTrackLoading;

  bool get canSeek => widget.canSeek;

  VoidCallback? get onSeekStart => widget.onSeekStart;

  ValueChanged<Duration>? get onSeekUpdate => widget.onSeekUpdate;

  VoidCallback? get onSeekEnd => widget.onSeekEnd;

  VoidCallback? get onSeekCancel => widget.onSeekCancel;

  VoidCallback? get onRetry => widget.onRetry;

  Widget? get playbackLayer => widget.playbackLayer;

  Widget? get seekBar => widget.seekBar;

  BoxFit get videoFit => widget.videoFit;

  bool get forYouLayout => widget.forYouLayout;

  bool get showChromeOverlays => widget.showChromeOverlays;

  Duration get chromeOverlayFadeDuration => widget.chromeOverlayFadeDuration;

  bool get isLiked => widget.isLiked;

  bool get isLikeLoading => widget.isLikeLoading;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final bottomFrameHeight = PlayerChrome.videoViewportBottomInset(
      forYouLayout: forYouLayout,
      bottomInset: bottomInset,
    );
    final forYouWatchNowBottom =
        bottomInset + _PlayerLayoutMetrics.forYouWatchNowBottom;
    final forYouMetaBottom =
        forYouWatchNowBottom + _PlayerLayoutMetrics.forYouMetaGap;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showViewportBackdrop)
          const Positioned.fill(child: ColoredBox(color: AppColors.black)),
        _PlayerPosterLayer(
          content: content,
          bottomFrameHeight: bottomFrameHeight,
          forYouLayout: forYouLayout,
          showViewportBackdrop: showViewportBackdrop,
          playbackLayer: playbackLayer,
          showLoading: showLoading,
          playbackError: playbackError,
          onRetry: onRetry,
        ),
        if (showChromeOverlays)
          _PlayerGradientLayer(
            bottomFrameHeight: bottomFrameHeight,
            forYouLayout: forYouLayout,
          ),
        if (isPlaying || showCenterPlayButton)
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            bottom: bottomFrameHeight,
            child: GestureDetector(
              key: const ValueKey('player_video_tap_layer'),
              behavior: HitTestBehavior.translucent,
              onTap: _handleVideoTap,
            ),
          ),
        if (!forYouLayout) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomFrameHeight,
            child: const ColoredBox(color: Color(0xFF141414)),
          ),
        ],
        if (showUnlockButton)
          _PlayerUnlockOverlay(
            label: unlockLabel ?? context.l10n.playerUnlockNow,
            bottomInset: bottomFrameHeight,
            onTap: onUnlockTap,
          )
        else if (showCenterPlayButton)
          _CenterPlayButton(onTap: onTogglePlay),
        if (_showPauseFeedback) const _PauseFeedbackIcon(),
        _PlayerActionRailLayer(
          bottomInset: bottomInset,
          forYouLayout: forYouLayout,
          overlayOpacity: overlayOpacity,
          overlayOpacityListenable: overlayOpacityListenable,
          likeCountLabel: content.likeCountLabel,
          dramaId: content.id,
          onEpisodesTap: onEpisodesTap,
          onShareTap: onShareTap,
          onMoreTap: onMoreTap,
          onLikeTap: onLikeTap,
          isLiked: isLiked,
          isLikeLoading: isLikeLoading,
          showChromeOverlays: showChromeOverlays,
          chromeOverlayFadeDuration: chromeOverlayFadeDuration,
        ),
        _PlayerMetaLayer(
          content: content,
          bottom: forYouLayout
              ? forYouMetaBottom
              : bottomInset + _PlayerLayoutMetrics.singleMetaBottom,
          forYouLayout: forYouLayout,
          overlayOpacity: overlayOpacity,
          overlayOpacityListenable: overlayOpacityListenable,
          showChromeOverlays: showChromeOverlays,
          chromeOverlayFadeDuration: chromeOverlayFadeDuration,
        ),
        if (forYouLayout) ...[
          if (!showUnlockButton)
            _PlayerWatchNowLayer(
              bottom: forYouWatchNowBottom,
              overlayOpacity: overlayOpacity,
              overlayOpacityListenable: overlayOpacityListenable,
              onTap: onWatchNowTap,
            ),
        ] else ...[
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + _PlayerLayoutMetrics.singleSeekBarBottom,
            child: RepaintBoundary(
              key: const ValueKey('player_seekbar_repaint_boundary'),
              child:
                  seekBar ??
                  (canSeek || duration > Duration.zero || showTrackLoading
                      ? PlayerSeekBar(
                          position: position,
                          duration: duration,
                          bufferedPosition: bufferedPosition,
                          previewPosition: seekPreviewPosition,
                          thumbnailAssetPath: content.posterAssetPath,
                          previewConfig: PlayerSeekPreviewConfig.fromPolicy(
                            PlayerPerformancePolicy.stable,
                          ),
                          isDragging: isSeeking,
                          showTrackLoading: showTrackLoading,
                          enabled: canSeek,
                          onDragStart: onSeekStart,
                          onDragUpdate: onSeekUpdate,
                          onDragEnd: onSeekEnd,
                          onDragCancel: onSeekCancel,
                        )
                      : const SizedBox.shrink()),
            ),
          ),
        ],
      ],
    );
  }

  void _handleVideoTap() {
    if (isPlaying) {
      _feedbackTimer?.cancel();
      setState(() => _showPauseFeedback = true);
      _feedbackTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted) {
          setState(() => _showPauseFeedback = false);
        }
      });
    }
    onTogglePlay();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }
}

class _PlayerPosterLayer extends StatelessWidget {
  const _PlayerPosterLayer({
    required this.content,
    required this.bottomFrameHeight,
    required this.forYouLayout,
    required this.showViewportBackdrop,
    required this.showLoading,
    required this.playbackError,
    this.playbackLayer,
    this.onRetry,
  });

  final PlayerContent content;
  final double bottomFrameHeight;
  final bool forYouLayout;
  final bool showViewportBackdrop;
  final bool showLoading;
  final bool playbackError;
  final Widget? playbackLayer;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('player_video_viewport'),
      left: 0,
      top: 0,
      right: 0,
      bottom: bottomFrameHeight,
      child: ClipRRect(
        borderRadius: forYouLayout
            ? const BorderRadius.vertical(bottom: Radius.circular(10))
            : BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showViewportBackdrop)
              const RepaintBoundary(
                key: ValueKey('player_poster_repaint_boundary'),
                child: ColoredBox(color: AppColors.black),
              ),
            ?playbackLayer,
            if (showLoading)
              const RepaintBoundary(child: _PlaybackLoadingOverlay()),
            if (playbackError)
              RepaintBoundary(child: _PlaybackRetryOverlay(onRetry: onRetry)),
          ],
        ),
      ),
    );
  }
}

class _PlayerGradientLayer extends StatelessWidget {
  const _PlayerGradientLayer({
    required this.bottomFrameHeight,
    required this.forYouLayout,
  });

  final double bottomFrameHeight;
  final bool forYouLayout;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: bottomFrameHeight,
      child: IgnorePointer(
        child: RepaintBoundary(
          key: const ValueKey('player_gradient_repaint_boundary'),
          child: ClipRRect(
            borderRadius: forYouLayout
                ? const BorderRadius.vertical(bottom: Radius.circular(10))
                : BorderRadius.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: forYouLayout ? 0.28 : 0.78),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: forYouLayout ? 0.58 : 0.72),
                  ],
                  stops: const [0, 0.2, 0.68, 1],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerActionRailLayer extends StatelessWidget {
  const _PlayerActionRailLayer({
    required this.bottomInset,
    required this.forYouLayout,
    required this.overlayOpacity,
    required this.overlayOpacityListenable,
    required this.likeCountLabel,
    required this.dramaId,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onMoreTap,
    required this.onLikeTap,
    required this.isLiked,
    required this.isLikeLoading,
    required this.showChromeOverlays,
    required this.chromeOverlayFadeDuration,
  });

  final double bottomInset;
  final bool forYouLayout;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final String likeCountLabel;
  final String dramaId;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback onLikeTap;
  final bool isLiked;
  final bool isLikeLoading;
  final bool showChromeOverlays;
  final Duration chromeOverlayFadeDuration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 17,
      bottom:
          bottomInset +
          (forYouLayout
              ? _PlayerLayoutMetrics.forYouActionRailBottom
              : _PlayerLayoutMetrics.singleActionRailBottom),
      child: AnimatedOpacity(
        key: const ValueKey('player_chrome_visibility_action_rail'),
        opacity: showChromeOverlays ? 1 : 0,
        duration: chromeOverlayFadeDuration,
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !showChromeOverlays,
          child: RepaintBoundary(
            key: const ValueKey('player_action_rail_repaint_boundary'),
            child: _OverlayOpacity(
              opacity: overlayOpacity,
              opacityListenable: overlayOpacityListenable,
              child: _PlayerActionRailContent(
                likeCountLabel: likeCountLabel,
                dramaId: dramaId,
                onEpisodesTap: onEpisodesTap,
                onShareTap: onShareTap,
                onMoreTap: onMoreTap,
                onLikeTap: onLikeTap,
                isLiked: isLiked,
                isLikeLoading: isLikeLoading,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerMetaLayer extends StatelessWidget {
  const _PlayerMetaLayer({
    required this.content,
    required this.bottom,
    required this.forYouLayout,
    required this.overlayOpacity,
    required this.overlayOpacityListenable,
    required this.showChromeOverlays,
    required this.chromeOverlayFadeDuration,
  });

  final PlayerContent content;
  final double bottom;
  final bool forYouLayout;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final bool showChromeOverlays;
  final Duration chromeOverlayFadeDuration;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 91,
      bottom: bottom,
      child: AnimatedOpacity(
        key: const ValueKey('player_chrome_visibility_meta'),
        opacity: showChromeOverlays ? 1 : 0,
        duration: chromeOverlayFadeDuration,
        curve: Curves.easeOut,
        child: IgnorePointer(
          ignoring: !showChromeOverlays,
          child: RepaintBoundary(
            key: const ValueKey('player_meta_repaint_boundary'),
            child: _OverlayOpacity(
              opacity: overlayOpacity,
              opacityListenable: overlayOpacityListenable,
              child: PlayerBottomMeta(
                content: content,
                showChevron: !forYouLayout,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerWatchNowLayer extends StatelessWidget {
  const _PlayerWatchNowLayer({
    required this.bottom,
    required this.overlayOpacity,
    required this.overlayOpacityListenable,
    required this.onTap,
  });

  final double bottom;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 98,
      bottom: bottom,
      child: RepaintBoundary(
        key: const ValueKey('player_watch_now_repaint_boundary'),
        child: _OverlayOpacity(
          opacity: overlayOpacity,
          opacityListenable: overlayOpacityListenable,
          child: _WatchNowButton(onTap: onTap),
        ),
      ),
    );
  }
}

class _OverlayOpacity extends StatelessWidget {
  const _OverlayOpacity({
    required this.opacity,
    required this.child,
    this.opacityListenable,
  });

  final double opacity;
  final ValueListenable<double>? opacityListenable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = opacityListenable;
    if (listenable != null) {
      return ValueListenableBuilder<double>(
        valueListenable: listenable,
        builder: (context, value, child) {
          return AnimatedOpacity(
            key: const ValueKey('player_overlay_opacity'),
            opacity: value,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            child: child,
          );
        },
        child: child,
      );
    }
    return AnimatedOpacity(
      key: const ValueKey('player_overlay_opacity'),
      opacity: opacity,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: child,
    );
  }
}

class _PlaybackLoadingOverlay extends StatelessWidget {
  const _PlaybackLoadingOverlay();

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

class _PlaybackRetryOverlay extends StatelessWidget {
  const _PlaybackRetryOverlay({required this.onRetry});

  final VoidCallback? onRetry;

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

class _CenterPlayButton extends StatelessWidget {
  const _CenterPlayButton({required this.onTap});

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

class _PlayerUnlockOverlay extends StatelessWidget {
  const _PlayerUnlockOverlay({
    required this.label,
    required this.bottomInset,
    required this.onTap,
  });

  final String label;
  final double bottomInset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: bottomInset,
      child: RepaintBoundary(
        key: const ValueKey('player_unlock_repaint_boundary'),
        child: Center(
          child: GestureDetector(
            key: const ValueKey('player_unlock_button'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 275,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 18 / 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseFeedbackIcon extends StatelessWidget {
  const _PauseFeedbackIcon();

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

class PlayerActionRail extends StatelessWidget {
  const PlayerActionRail({
    required this.likeCountLabel,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onMoreTap,
    required this.onLikeTap,
    required this.isLiked,
    required this.isLikeLoading,
    super.key,
  });

  final String likeCountLabel;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback onLikeTap;
  final bool isLiked;
  final bool isLikeLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LikeActionItem(
          label: likeCountLabel,
          isLiked: isLiked,
          isLoading: isLikeLoading,
          onTap: onLikeTap,
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.layers_rounded,
          label: context.l10n.playerEpisodes,
          onTap: onEpisodesTap,
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.reply_rounded,
          label: context.l10n.playerShare,
          onTap: onShareTap,
          flipIcon: true,
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.more_horiz_rounded,
          label: context.l10n.playerMore,
          onTap: onMoreTap,
        ),
      ],
    );
  }
}

/// 处理点赞数缓存的 action rail 内容。
class _PlayerActionRailContent extends ConsumerWidget {
  const _PlayerActionRailContent({
    required this.likeCountLabel,
    required this.dramaId,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onMoreTap,
    required this.onLikeTap,
    required this.isLiked,
    required this.isLikeLoading,
  });

  final String likeCountLabel;
  final String dramaId;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback onLikeTap;
  final bool isLiked;
  final bool isLikeLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取实时的点赞数显示文案
    final displayLikeCountLabel = ref.watch(
      playerLikeCountProvider((likeCountLabel, dramaId)),
    );

    return Column(
      children: [
        _LikeActionItem(
          label: displayLikeCountLabel,
          isLiked: isLiked,
          isLoading: isLikeLoading,
          onTap: onLikeTap,
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.layers_rounded,
          imageIcon: Image.asset("assets/images/player/episodes.png",height: 28),
          label: context.l10n.playerEpisodes,
          onTap: onEpisodesTap,
        ),
        const SizedBox(height: 18),
        _ActionItem(
          icon: Icons.reply_rounded,
          label: context.l10n.playerShare,
          onTap: onShareTap,
          flipIcon: true,
        ),
        // const SizedBox(height: 18),
        // _ActionItem(
        //   icon: Icons.more_horiz_rounded,
        //   label: context.l10n.playerMore,
        //   onTap: onMoreTap,
        // ),
      ],
    );
  }
}

class _WatchNowButton extends StatelessWidget {
  const _WatchNowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          context.l10n.playerWatchNow,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 18 / 14,
          ),
        ),
      ),
    );
  }
}

class PlayerBottomMeta extends StatelessWidget {
  const PlayerBottomMeta({
    required this.content,
    this.showChevron = true,
    super.key,
  });

  final PlayerContent content;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          showChevron ? '${content.playTitle} >' : content.playTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 20 / 16,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: _truncate(content.synopsis, 62),
            children: [
              TextSpan(
                text: ' ${context.l10n.playerMore}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 18 / 14,
          ),
        ),
      ],
    );
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }

    return '${value.substring(0, maxLength)}...';
  }
}

class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    required this.position,
    required this.duration,
    required this.bufferedPosition,
    required this.enabled,
    required this.isDragging,
    required this.showTrackLoading,
    required this.thumbnailAssetPath,
    required this.previewConfig,
    this.hasThumbnailPreviewAsset = false,
    this.isPassiveTrack = false,
    this.trackFadeDuration = Duration.zero,
    this.previewPosition,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final String thumbnailAssetPath;
  final bool hasThumbnailPreviewAsset;
  final PlayerSeekPreviewConfig previewConfig;
  final bool isPassiveTrack;
  final Duration trackFadeDuration;
  final Duration? previewPosition;
  final bool enabled;
  final bool isDragging;
  final bool showTrackLoading;
  final VoidCallback? onDragStart;
  final ValueChanged<Duration>? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragCancel;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  @override
  Widget build(BuildContext context) {
    final progress = _ratio(widget.previewPosition ?? widget.position);
    final buffered = _ratio(widget.bufferedPosition);
    final config = widget.previewConfig;
    final showThumbnail =
        widget.isDragging &&
        config.allowThumbnailPreview &&
        widget.hasThumbnailPreviewAsset &&
        widget.thumbnailAssetPath.isNotEmpty;
    final showTimeBubble =
        widget.isDragging && config.allowTimeBubble && !showThumbnail;
    final barHeight = widget.isDragging ? 4.0 : 2.0;
    final trackOpacity = widget.isPassiveTrack ? 0.42 : 1.0;
    final stackHeight = showThumbnail
        ? 112.0
        : showTimeBubble
        ? 40.0
        : 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const thumbnailWidth = 124.0;
        final thumbnailLeft = (progress * width - thumbnailWidth / 2).clamp(
          0.0,
          (width - thumbnailWidth).clamp(0.0, width),
        );
        const timeBubbleWidth = 108.0;
        final timeBubbleLeft = (progress * width - timeBubbleWidth / 2).clamp(
          0.0,
          (width - timeBubbleWidth).clamp(0.0, width),
        );

        return GestureDetector(
          key: const ValueKey('player_seek_bar'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.enabled
              ? (details) {
                  widget.onDragStart?.call();
                  _emitPosition(details.localPosition.dx, width);
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (details) {
                  _emitPosition(details.localPosition.dx, width);
                }
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  widget.onDragEnd?.call();
                }
              : null,
          onHorizontalDragCancel: widget.enabled
              ? () {
                  widget.onDragCancel?.call();
                }
              : null,
          child: SizedBox(
            height: stackHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (showThumbnail)
                  Positioned(
                    left: thumbnailLeft,
                    bottom: 30,
                    width: thumbnailWidth,
                    child: _SeekThumbnailPreview(
                      assetPath: widget.thumbnailAssetPath,
                      position: widget.previewPosition ?? widget.position,
                      duration: widget.duration,
                      useShadow: config.allowPreviewShadow,
                    ),
                  ),
                if (showTimeBubble)
                  Positioned(
                    left: timeBubbleLeft,
                    bottom: 22,
                    width: timeBubbleWidth,
                    child: _SeekTimeBubble(
                      position: widget.previewPosition ?? widget.position,
                      duration: widget.duration,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
                  child: AnimatedOpacity(
                    key: const ValueKey('player_seek_track_shell'),
                    opacity: trackOpacity,
                    duration: widget.trackFadeDuration,
                    curve: Curves.easeOut,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: barHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ColoredBox(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            if (!widget.isPassiveTrack)
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: buffered,
                                child: ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: widget.isPassiveTrack ? 0 : progress,
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.78),
                              ),
                            ),
                            if (widget.showTrackLoading && !widget.isDragging)
                              const _SeekTrackLoadingAnimation(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _emitPosition(double localDx, double width) {
    if (width <= 0 || widget.duration <= Duration.zero) {
      return;
    }
    final ratio = (localDx / width).clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (widget.duration.inMilliseconds * ratio).round(),
    );
    widget.onDragUpdate?.call(target);
  }

  double _ratio(Duration value) {
    if (widget.duration <= Duration.zero) {
      return 0;
    }
    return (value.inMilliseconds / widget.duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }
}

class _SeekTrackLoadingAnimation extends StatelessWidget {
  const _SeekTrackLoadingAnimation();

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      key: const ValueKey('player_seek_track_loading'),
      minHeight: 2,
      backgroundColor: Colors.transparent,
      valueColor: AlwaysStoppedAnimation<Color>(
        Colors.white.withValues(alpha: 0.68),
      ),
    );
  }
}

class _SeekThumbnailPreview extends StatelessWidget {
  const _SeekThumbnailPreview({
    required this.assetPath,
    required this.position,
    required this.duration,
    required this.useShadow,
  });

  final String assetPath;
  final Duration position;
  final Duration duration;
  final bool useShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player_seek_thumbnail_preview'),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
        boxShadow: useShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(assetPath, fit: BoxFit.cover),
          if (useShadow)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.56),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 6,
            child: Text(
              '${_SeekTimeLabel.format(position)} / ${_SeekTimeLabel.format(duration)}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 13 / 11,
                shadows: useShadow
                    ? const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 轻量拖动时间气泡（stable）：无图、无阴影，仅半透明底 + 文本。
class _SeekTimeBubble extends StatelessWidget {
  const _SeekTimeBubble({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player_seek_time_bubble'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${_SeekTimeLabel.format(position)} / ${_SeekTimeLabel.format(duration)}',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 13 / 11,
        ),
      ),
    );
  }
}

abstract final class _SeekTimeLabel {
  static String format(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.flipIcon = false,
    this.imageIcon,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool flipIcon;
  final Widget? imageIcon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: Colors.white, size: 30);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              flipIcon
                  ? Transform.flip(flipX: true, child: iconWidget)
                  : imageIcon ?? iconWidget,
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 点赞按钮组件。
class _LikeActionItem extends StatelessWidget {
  const _LikeActionItem({
    required this.label,
    required this.isLiked,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLiked;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isLoading ? null : onTap,
        child: SizedBox(
          width: 58,
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                )
              else
                Icon(
                  isLiked ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isLiked ? const Color(0xFFFFD700) : Colors.white,
                  size: 30,
                ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLiked ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 16 / 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
