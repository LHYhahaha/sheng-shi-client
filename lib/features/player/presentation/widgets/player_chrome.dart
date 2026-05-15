import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/player_content.dart';

abstract final class _PlayerLayoutMetrics {
  static const forYouActionRailBottom = 160.0;
  static const singleActionRailBottom = 161.0;
  static const forYouWatchNowBottom = 24.0;
  static const forYouMetaGap = 58.0;
  static const singleBottomFrameHeight = 79.0;
  static const singleBottomActionBottom = 41.0;
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
    this.showUnlockButton = false,
    this.unlockLabel,
    this.overlayOpacity = 1.0,
    this.overlayOpacityListenable,
    this.showViewportBackdrop = true,
    this.showVideo = true,
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
    this.onDownloadTap,
    this.videoController,
    this.playbackLayer,
    this.seekBar,
    this.videoFit = BoxFit.cover,
    this.forYouLayout = false,
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
  final bool showUnlockButton;
  final String? unlockLabel;
  final double overlayOpacity;
  final ValueListenable<double>? overlayOpacityListenable;
  final bool showViewportBackdrop;
  final bool showVideo;
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
  final VoidCallback? onDownloadTap;
  final VideoController? videoController;
  final Widget? playbackLayer;
  final Widget? seekBar;
  final BoxFit videoFit;
  final bool forYouLayout;

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
  bool get showUnlockButton => widget.showUnlockButton;
  String? get unlockLabel => widget.unlockLabel;
  double get overlayOpacity => widget.overlayOpacity;
  ValueListenable<double>? get overlayOpacityListenable =>
      widget.overlayOpacityListenable;
  bool get showViewportBackdrop => widget.showViewportBackdrop;
  bool get showVideo => widget.showVideo;
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
  VoidCallback? get onDownloadTap => widget.onDownloadTap;
  VideoController? get videoController => widget.videoController;
  Widget? get playbackLayer => widget.playbackLayer;
  Widget? get seekBar => widget.seekBar;
  BoxFit get videoFit => widget.videoFit;
  bool get forYouLayout => widget.forYouLayout;

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
        Positioned(
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
                  Image.asset(content.backgroundAssetPath, fit: BoxFit.cover),
                ?playbackLayer,
                if (videoController != null)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: showVideo ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Video(
                        controller: videoController!,
                        controls: NoVideoControls,
                        fit: videoFit,
                      ),
                    ),
                  ),
                if (showLoading) const _PlaybackLoadingOverlay(),
                if (playbackError) _PlaybackRetryOverlay(onRetry: onRetry),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: bottomFrameHeight,
          child: IgnorePointer(
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
                      Colors.black.withValues(
                        alpha: forYouLayout ? 0.28 : 0.78,
                      ),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(
                        alpha: forYouLayout ? 0.58 : 0.72,
                      ),
                    ],
                    stops: const [0, 0.2, 0.68, 1],
                  ),
                ),
              ),
            ),
          ),
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
          _CenterUnlockButton(
            label: unlockLabel ?? context.l10n.playerUnlockNow,
            bottomInset: bottomFrameHeight,
            onTap: onUnlockTap,
          )
        else if (showCenterPlayButton)
          _CenterPlayButton(onTap: onTogglePlay),
        if (_showPauseFeedback) const _PauseFeedbackIcon(),
        Positioned(
          right: 17,
          bottom:
              bottomInset +
              (forYouLayout
                  ? _PlayerLayoutMetrics.forYouActionRailBottom
                  : _PlayerLayoutMetrics.singleActionRailBottom),
          child: _OverlayOpacity(
            opacity: overlayOpacity,
            opacityListenable: overlayOpacityListenable,
            child: PlayerActionRail(
              likeCountLabel: content.likeCountLabel,
              onEpisodesTap: onEpisodesTap,
              onShareTap: onShareTap,
              onMoreTap: onMoreTap,
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 91,
          bottom: forYouLayout ? forYouMetaBottom : bottomInset + 91,
          child: _OverlayOpacity(
            opacity: overlayOpacity,
            opacityListenable: overlayOpacityListenable,
            child: PlayerBottomMeta(
              content: content,
              showChevron: !forYouLayout,
            ),
          ),
        ),
        if (forYouLayout) ...[
          if (!showUnlockButton)
            Positioned(
              left: 16,
              right: 98,
              bottom: forYouWatchNowBottom,
              child: _OverlayOpacity(
                opacity: overlayOpacity,
                opacityListenable: overlayOpacityListenable,
                child: _WatchNowButton(onTap: onWatchNowTap),
              ),
            ),
        ] else ...[
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 78,
            child:
                seekBar ??
                (canSeek || duration > Duration.zero || showTrackLoading
                    ? PlayerSeekBar(
                        position: position,
                        duration: duration,
                        bufferedPosition: bufferedPosition,
                        previewPosition: seekPreviewPosition,
                        thumbnailAssetPath: content.posterAssetPath,
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
          if (!showUnlockButton)
            Positioned(
              left: 16,
              bottom:
                  bottomInset + _PlayerLayoutMetrics.singleBottomActionBottom,
              child: _OverlayOpacity(
                opacity: overlayOpacity,
                opacityListenable: overlayOpacityListenable,
                child: GestureDetector(
                  key: const ValueKey('player_member_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onUnlockTap,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 168),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.playerBecomeMember,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B2C0D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 16 / 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 31,
            bottom: bottomInset + _PlayerLayoutMetrics.singleBottomActionBottom,
            child: _OverlayOpacity(
              opacity: overlayOpacity,
              opacityListenable: overlayOpacityListenable,
              child: GestureDetector(
                key: const ValueKey('player_download_button'),
                behavior: HitTestBehavior.opaque,
                onTap: onDownloadTap,
                child: Row(
                  children: [
                    const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.playerDownload,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 14 / 12,
                      ),
                    ),
                  ],
                ),
              ),
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

class _CenterUnlockButton extends StatelessWidget {
  const _CenterUnlockButton({
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
    super.key,
  });

  final String likeCountLabel;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionItem(
          icon: Icons.star_rounded,
          label: likeCountLabel,
          onTap: () {},
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
    final barHeight = widget.isDragging ? 4.0 : 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bubbleWidth = 116.0;
        final thumbnailWidth = 82.0;
        final bubbleLeft = (progress * width - bubbleWidth / 2).clamp(
          0.0,
          (width - bubbleWidth).clamp(0.0, width),
        );
        final thumbnailLeft = (progress * width - thumbnailWidth / 2).clamp(
          0.0,
          (width - thumbnailWidth).clamp(0.0, width),
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
            height: widget.isDragging ? 98 : 20,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (widget.isDragging)
                  Positioned(
                    left: thumbnailLeft,
                    bottom: 45,
                    width: thumbnailWidth,
                    child: _SeekThumbnailPreview(
                      assetPath: widget.thumbnailAssetPath,
                    ),
                  ),
                if (widget.isDragging)
                  Positioned(
                    left: bubbleLeft,
                    bottom: 14,
                    width: bubbleWidth,
                    child: _SeekTimeBubble(
                      position: widget.previewPosition ?? widget.position,
                      duration: widget.duration,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 6,
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
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: buffered,
                            child: ColoredBox(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
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

class _SeekTimeBubble extends StatelessWidget {
  const _SeekTimeBubble({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '${_format(position)} / ${_format(duration)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 14 / 12,
          ),
        ),
      ),
    );
  }

  String _format(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _SeekThumbnailPreview extends StatelessWidget {
  const _SeekThumbnailPreview({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('player_seek_thumbnail_preview'),
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(assetPath, fit: BoxFit.cover),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.flipIcon = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool flipIcon;

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
                  : iconWidget,
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
