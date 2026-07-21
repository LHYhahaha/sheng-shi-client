import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../application/player_like_controller.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_runtime_coordinator.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/player_feed.dart';
import 'player_chrome.dart';
import 'player_playback_layer.dart';

/// PageView 单页轻量 shell：海报/文案/按钮，不含真实 Video（Video 在顶层 surface）。
///
/// 权益展示只读：经 [PlayerAccessPresenter]（与 engine 同源），不在此触发 evaluate/play。
class PlayerFeedPageShell extends ConsumerWidget {
  const PlayerFeedPageShell({
    required this.sessionKey,
    required this.item,
    required this.index,
    required this.isSettledPage,
    required this.forYouLayout,
    required this.allowPressChromeDimming,
    this.overlayOpacityListenable,
    required this.onTogglePlay,
    required this.onRetry,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSeekCancel,
    required this.onWatchNowTap,
    required this.onEpisodesTap,
    required this.onShareTap,
    required this.onMoreTap,
    required this.onUnlockTap,
    required this.onOpenMembership,
    this.onSearchTap,
    this.onMetaTap,
    this.showChromeOverlays = true,
    this.chromeOverlayFadeDuration = Duration.zero,
    this.useSingleDramaChromeTap = false,
    this.onExitImmersiveChrome,
    this.onSingleDramaUserInteraction,
    super.key,
  });

  final String sessionKey;
  final PlayerFeedItem item;
  final int index;
  final bool isSettledPage;
  final bool forYouLayout;
  final bool allowPressChromeDimming;
  final ValueListenable<double>? overlayOpacityListenable;
  final void Function({required bool pauseRequested}) onTogglePlay;
  final VoidCallback onRetry;
  final VoidCallback onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final VoidCallback onSeekEnd;
  final VoidCallback onSeekCancel;
  final VoidCallback onWatchNowTap;
  final VoidCallback onEpisodesTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final VoidCallback onUnlockTap;
  final VoidCallback onOpenMembership;
  final VoidCallback? onSearchTap;
  final VoidCallback? onMetaTap;
  final bool showChromeOverlays;
  final Duration chromeOverlayFadeDuration;
  final bool useSingleDramaChromeTap;
  final VoidCallback? onExitImmersiveChrome;
  final VoidCallback? onSingleDramaUserInteraction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementControllerProvider);
    // 与 PlayerFeedEngine.accessPresentationFor 同源；勿在 select 内 ref.read。
    final accessPresentation = ref.watch(
      playerRuntimeCoordinatorProvider(sessionKey).select(
        (state) => state.accessPresenter.presentationFor(item, entitlement),
      ),
    );
    final playbackShell = isSettledPage
        ? ref.watch(
            playerPlaybackControllerProvider(
              sessionKey,
            ).select(PlayerPlaybackShellSnapshot.fromState),
          )
        : null;

    // 获取点赞状态
    // 始终监听 provider，避免在页面稳定时从初始状态切换到真实状态导致闪烁
    final likeState = ref.watch(playerLikeControllerProvider(item.content.id));

    final isLockedSettledPage =
        isSettledPage &&
        (accessPresentation == PlayerAccessPresentationState.lockedCoins ||
            accessPresentation ==
                PlayerAccessPresentationState.lockedRecharge ||
            accessPresentation ==
                PlayerAccessPresentationState.lockedMembership);
    final lockedActionLabel =
        accessPresentation == PlayerAccessPresentationState.lockedMembership
        ? context.l10n.playerMemberUnlock
        : context.l10n.playerUnlockNow;
    final shell = playbackShell;
    final canUsePlaybackSurface =
        isSettledPage &&
        accessPresentation == PlayerAccessPresentationState.playable &&
        shell != null &&
        shell.shouldAttachVideoSurface &&
        shell.currentItemId == item.id &&
        shell.currentSource != null;
    final canHideViewportBackdrop =
        canUsePlaybackSurface && shell.hasVideoController;

    return Stack(
      children: [
        PlayerChrome(
          content: item.content,
          overlayOpacityListenable: allowPressChromeDimming
              ? overlayOpacityListenable
              : null,
          showViewportBackdrop: !canHideViewportBackdrop,
          showChromeOverlays: showChromeOverlays,
          chromeOverlayFadeDuration: chromeOverlayFadeDuration,
          playbackLayer: canUsePlaybackSurface
              ? PlayerPlaybackControlsConsumer(
                  sessionKey: sessionKey,
                  itemId: item.id,
                  onTogglePlay: onTogglePlay,
                  onRetry: onRetry,
                  useSingleDramaChromeTap: useSingleDramaChromeTap,
                  onExitImmersiveChrome: onExitImmersiveChrome,
                  onSingleDramaUserInteraction: onSingleDramaUserInteraction,
                )
              : null,
          videoFit: videoFitForEpisode(item.episode),
          seekBar:
              !forYouLayout &&
                  isSettledPage &&
                  accessPresentation == PlayerAccessPresentationState.playable
              ? PlayerSeekBarConsumer(
                  sessionKey: sessionKey,
                  itemId: item.id,
                  fallbackDuration: item.episode.duration,
                  thumbnailAssetPath: item.content.posterAssetPath,
                  onSeekStart: onSeekStart,
                  onSeekUpdate: onSeekUpdate,
                  onSeekEnd: onSeekEnd,
                  onSeekCancel: onSeekCancel,
                )
              : null,
          isPlaying: false,
          showCenterPlayButton: false,
          onTogglePlay: () {},
          onWatchNowTap:
              _canOpenWatchNow(
                forYouLayout: forYouLayout,
                item: item,
                accessPresentation: accessPresentation,
                shell: shell,
              )
              ? onWatchNowTap
              : () {},
          onEpisodesTap: onEpisodesTap,
          onShareTap: onShareTap,
          onMoreTap: onMoreTap,
          onMetaTap: onMetaTap,
          onLikeTap: isSettledPage
              ? () {
                  ref
                      .read(
                        playerLikeControllerProvider(item.content.id).notifier,
                      )
                      .toggleLike();
                }
              : () {},
          onSearchTap: onSearchTap ?? () {},
          showUnlockButton: isLockedSettledPage,
          unlockLabel: lockedActionLabel,
          onUnlockTap: isLockedSettledPage
              ? (accessPresentation ==
                        PlayerAccessPresentationState.lockedMembership
                    ? onOpenMembership
                    : onUnlockTap)
              : () {},
          forYouLayout: forYouLayout,
          isLiked: likeState.isLiked,
          isLikeLoading: likeState.isLoading,
        ),
        if (item.episode.isUnavailable)
          UnavailableEpisodeOverlay(
            message: context.l10n.playerEpisodeUnavailable,
          ),
      ],
    );
  }

  bool _canOpenWatchNow({
    required bool forYouLayout,
    required PlayerFeedItem item,
    required PlayerAccessPresentationState accessPresentation,
    required PlayerPlaybackShellSnapshot? shell,
  }) {
    if (forYouLayout) {
      return item.content.id.isNotEmpty && item.episode.id.isNotEmpty;
    }
    return accessPresentation == PlayerAccessPresentationState.playable &&
        shell != null &&
        shell.canTogglePlayback &&
        shell.currentItemId == item.id;
  }
}
