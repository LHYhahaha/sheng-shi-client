import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_runtime_coordinator.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/player_feed.dart';
import 'player_chrome.dart';
import 'player_playback_layer.dart';

/// One PageView page: static chrome + settled-only interactive playback UI.
class PlayerFeedPageShell extends ConsumerWidget {
  const PlayerFeedPageShell({
    required this.sessionKey,
    required this.item,
    required this.index,
    required this.isSettledPage,
    required this.forYouLayout,
    required this.overlayOpacityListenable,
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
    this.onDownloadTap,
    super.key,
  });

  final String sessionKey;
  final PlayerFeedItem item;
  final int index;
  final bool isSettledPage;
  final bool forYouLayout;
  final ValueListenable<double> overlayOpacityListenable;
  final VoidCallback onTogglePlay;
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
  final VoidCallback? onDownloadTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementControllerProvider);
    final accessPresentation = ref.watch(
      playerRuntimeCoordinatorProvider(sessionKey).select(
        (state) => state.accessPresenter.presentationFor(item, entitlement),
      ),
    );
    final playbackShell = isSettledPage
        ? ref.watch(
            playerPlaybackControllerProvider(sessionKey).select(
              PlayerPlaybackShellSnapshot.fromState,
            ),
          )
        : null;

    final isLockedSettledPage =
        isSettledPage &&
        (accessPresentation == PlayerAccessPresentationState.lockedCoins ||
            accessPresentation == PlayerAccessPresentationState.lockedRecharge ||
            accessPresentation == PlayerAccessPresentationState.lockedMembership);
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
          overlayOpacityListenable: overlayOpacityListenable,
          showViewportBackdrop: !canHideViewportBackdrop,
          playbackLayer: canUsePlaybackSurface
              ? PlayerPlaybackControlsConsumer(
                  sessionKey: sessionKey,
                  itemId: item.id,
                  onTogglePlay: onTogglePlay,
                  onRetry: onRetry,
                )
              : null,
          videoFit: videoFitForEpisode(item.episode),
          seekBar:
              !forYouLayout &&
                  isSettledPage &&
                  accessPresentation == PlayerAccessPresentationState.playable
              ? PlayerSeekBarConsumer(
                  sessionKey: sessionKey,
                  thumbnailAssetPath: item.content.posterAssetPath,
                  onSeekStart: onSeekStart,
                  onSeekUpdate: onSeekUpdate,
                  onSeekEnd: onSeekEnd,
                  onSeekCancel: onSeekCancel,
                )
              : null,
          onDownloadTap: onDownloadTap,
          isPlaying: false,
          showCenterPlayButton: false,
          onTogglePlay: () {},
          onWatchNowTap:
              shell != null &&
                  shell.canTogglePlayback &&
                  shell.status == PlayerPlaybackStatus.paused
              ? onWatchNowTap
              : () {},
          onEpisodesTap: onEpisodesTap,
          onShareTap: onShareTap,
          onMoreTap: onMoreTap,
          showUnlockButton: isLockedSettledPage,
          unlockLabel: lockedActionLabel,
          onUnlockTap: isLockedSettledPage ? onUnlockTap : onOpenMembership,
          forYouLayout: forYouLayout,
        ),
        if (item.episode.isUnavailable)
          UnavailableEpisodeOverlay(
            message: context.l10n.playerEpisodeUnavailable,
          ),
      ],
    );
  }
}
