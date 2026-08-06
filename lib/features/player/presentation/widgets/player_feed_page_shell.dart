import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
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
class PlayerFeedPageShell extends ConsumerStatefulWidget {
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
  ConsumerState<PlayerFeedPageShell> createState() =>
      _PlayerFeedPageShellState();
}

class _PlayerFeedPageShellState extends ConsumerState<PlayerFeedPageShell> {
  @override
  void initState() {
    super.initState();
    _syncFeedLikeState();
  }

  @override
  void didUpdateWidget(covariant PlayerFeedPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.content.isFavorited != item.content.isFavorited ||
        oldWidget.item.content.favoriteCount != item.content.favoriteCount) {
      _syncFeedLikeState();
    }
  }

  void _syncFeedLikeState() {
    final isFavorited = item.content.isFavorited;
    final favoriteCount = item.content.favoriteCount;
    final dramaId = item.content.id;
    // PageView may create this child while its sliver is laying out. Riverpod
    // forbids state changes during that build phase, so defer the feed snapshot
    // until the frame has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.item.content.id != dramaId ||
          widget.item.content.isFavorited != isFavorited ||
          widget.item.content.favoriteCount != favoriteCount) {
        return;
      }
      ref
          .read(playerLikeControllerProvider(dramaId).notifier)
          .syncFeedLikeState(
            isLiked: isFavorited,
            favoriteCount: favoriteCount,
          );
    });
  }

  PlayerFeedItem get item => widget.item;
  String get sessionKey => widget.sessionKey;
  bool get isSettledPage => widget.isSettledPage;
  bool get forYouLayout => widget.forYouLayout;
  bool get allowPressChromeDimming => widget.allowPressChromeDimming;
  ValueListenable<double>? get overlayOpacityListenable =>
      widget.overlayOpacityListenable;
  void Function({required bool pauseRequested}) get onTogglePlay =>
      widget.onTogglePlay;
  VoidCallback get onRetry => widget.onRetry;
  VoidCallback get onSeekStart => widget.onSeekStart;
  ValueChanged<Duration> get onSeekUpdate => widget.onSeekUpdate;
  VoidCallback get onSeekEnd => widget.onSeekEnd;
  VoidCallback get onSeekCancel => widget.onSeekCancel;
  VoidCallback get onWatchNowTap => widget.onWatchNowTap;
  VoidCallback get onEpisodesTap => widget.onEpisodesTap;
  VoidCallback get onShareTap => widget.onShareTap;
  VoidCallback get onMoreTap => widget.onMoreTap;
  VoidCallback get onUnlockTap => widget.onUnlockTap;
  VoidCallback get onOpenMembership => widget.onOpenMembership;
  VoidCallback? get onSearchTap => widget.onSearchTap;
  VoidCallback? get onMetaTap => widget.onMetaTap;
  bool get showChromeOverlays => widget.showChromeOverlays;
  Duration get chromeOverlayFadeDuration => widget.chromeOverlayFadeDuration;
  bool get useSingleDramaChromeTap => widget.useSingleDramaChromeTap;
  VoidCallback? get onExitImmersiveChrome => widget.onExitImmersiveChrome;
  VoidCallback? get onSingleDramaUserInteraction =>
      widget.onSingleDramaUserInteraction;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
          episodeNumber: item.episode.number,
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
                  final favoriteAction = likeState.isLiked ? 'remove' : 'add';
                  unawaited(
                    ref
                        .read(analyticsServiceProvider)
                        .track(
                          AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                            'element_name': 'favorite_toggle_button',
                            'drama_id': item.content.id,
                            'favorite_action': favoriteAction,
                          }),
                        ),
                  );
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
              ? () {
                  final unlockButtonAction = switch (accessPresentation) {
                    PlayerAccessPresentationState.lockedCoins =>
                      'open_recharge_with_coin',
                    PlayerAccessPresentationState.lockedRecharge =>
                      'open_recharge_with_coin',
                    PlayerAccessPresentationState.lockedMembership =>
                      'open_recharge_vip_only',
                    _ => null,
                  };
                  if (unlockButtonAction != null) {
                    unawaited(
                      ref
                          .read(analyticsServiceProvider)
                          .track(
                            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                              'element_name': 'episode_unlock_button',
                              'drama_id': item.content.id,
                              'episode_id': item.episode.id,
                              'unlock_button_action': unlockButtonAction,
                            }),
                          ),
                    );
                  }
                  if (accessPresentation ==
                      PlayerAccessPresentationState.lockedMembership) {
                    onOpenMembership();
                    return;
                  }
                  onUnlockTap();
                }
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
