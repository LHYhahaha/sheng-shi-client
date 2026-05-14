import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/player_content.dart';

abstract final class _PlayerLayoutMetrics {
  static const forYouActionRailBottom = 160.0;
  static const singleActionRailBottom = 161.0;
  static const forYouWatchNowBottom = 24.0;
  static const forYouMetaGap = 58.0;
  static const singleBottomActionBottom = 41.0;
}

class PlayerChrome extends StatelessWidget {
  const PlayerChrome({
    required this.content,
    required this.episodeNumber,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onMoreTap,
    required this.onUnlockTap,
    this.showVideo = true,
    this.videoController,
    this.onBackTap,
    this.forYouLayout = false,
    super.key,
  });

  final PlayerContent content;
  final int episodeNumber;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback onUnlockTap;
  final bool showVideo;
  final VideoController? videoController;
  final VoidCallback? onBackTap;
  final bool forYouLayout;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final bottomFrameHeight = forYouLayout ? bottomInset : 0.0;
    final forYouWatchNowBottom =
        bottomInset + _PlayerLayoutMetrics.forYouWatchNowBottom;
    final forYouMetaBottom =
        forYouWatchNowBottom + _PlayerLayoutMetrics.forYouMetaGap;

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.black)),
        Positioned(
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
                Image.asset(content.backgroundAssetPath, fit: BoxFit.cover),
                if (videoController != null)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: showVideo ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: Video(
                        controller: videoController!,
                        controls: NoVideoControls,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: bottomFrameHeight,
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
        if (!forYouLayout) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 79 + bottomInset,
            child: const ColoredBox(color: Color(0xFF141414)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _IconTapTarget(
                    key: const ValueKey('player_back_button'),
                    icon: Icons.chevron_left,
                    iconSize: 28,
                    onTap:
                        onBackTap ??
                        () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(RoutePaths.home);
                          }
                        },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'EP.${episodeNumber.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 18 / 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.playerSpeed,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 18 / 14,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(Icons.more_horiz, color: Colors.white, size: 24),
                ],
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTogglePlay,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: isPlaying ? 0 : 1,
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
            ),
          ),
        ],
        Positioned(
          right: 17,
          bottom:
              bottomInset +
              (forYouLayout
                  ? _PlayerLayoutMetrics.forYouActionRailBottom
                  : _PlayerLayoutMetrics.singleActionRailBottom),
          child: PlayerActionRail(
            likeCountLabel: content.likeCountLabel,
            onEpisodesTap: onEpisodesTap,
            onShareTap: onShareTap,
            onMoreTap: onMoreTap,
          ),
        ),
        Positioned(
          left: 16,
          right: 91,
          bottom: forYouLayout ? forYouMetaBottom : bottomInset + 91,
          child: PlayerBottomMeta(content: content, showChevron: !forYouLayout),
        ),
        if (forYouLayout)
          Positioned(
            left: 16,
            right: 98,
            bottom: forYouWatchNowBottom,
            child: _WatchNowButton(onTap: onTogglePlay),
          )
        else ...[
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 78,
            child: const PlayerProgress(value: 0.2),
          ),
          Positioned(
            left: 16,
            bottom: bottomInset + _PlayerLayoutMetrics.singleBottomActionBottom,
            child: GestureDetector(
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
          Positioned(
            right: 31,
            bottom: bottomInset + _PlayerLayoutMetrics.singleBottomActionBottom,
            child: Row(
              children: [
                const Icon(
                  Icons.file_download_outlined,
                  color: Colors.white,
                  size: 22,
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
        ],
      ],
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

class PlayerProgress extends StatelessWidget {
  const PlayerProgress({required this.value, super.key});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          value: value,
          minHeight: 2,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
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

class _IconTapTarget extends StatelessWidget {
  const _IconTapTarget({
    required this.icon,
    required this.onTap,
    this.iconSize = 24,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 28,
        child: Center(
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
