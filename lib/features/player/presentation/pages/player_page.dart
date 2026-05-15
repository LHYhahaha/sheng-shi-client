import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_ui_controller.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_content.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_chrome.dart';
import '../widgets/player_detail_sheet.dart';

/// 播放器页面。
///
/// 页面负责手势、PageView、弹层和 shell chrome；真正的播放 source、preload、
/// prepared session window 和错误分类都交给 PlayerPlaybackController。这样 UI 可以
/// 随 feed 切换而重建，但播放器资源生命周期仍由同一个状态机保护。
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    required this.dramaId,
    required this.episodeId,
    this.feedMode = PlayerFeedMode.singleDrama,
    this.hideShellNavigation = false,
    this.initialPlaybackTrigger,
    this.initialUserActionAt,
    super.key,
  });

  const PlayerPage.forYou({super.key})
    : dramaId = null,
      episodeId = null,
      feedMode = PlayerFeedMode.forYou,
      hideShellNavigation = false,
      initialPlaybackTrigger = 'for_you_tab',
      initialUserActionAt = null;

  final String? dramaId;
  final String? episodeId;
  final PlayerFeedMode feedMode;
  final bool hideShellNavigation;
  final String? initialPlaybackTrigger;
  final DateTime? initialUserActionAt;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {
  static const _autoAdvanceDuration = Duration(milliseconds: 300);
  static const _pageTransitionDuration = Duration(milliseconds: 260);
  static const _topBarHorizontal = 16.0;
  static const _topBarTop = 8.0;
  static const _topBarHeight = 40.0;
  static const _topBarBackIconSize = 28.0;
  static const _topBarMoreIconSize = 24.0;
  static const _dimmedOverlayOpacity = 0.64;

  late final PageController _pageController;
  late final String _sessionKey;
  late final PlayerPlaybackController _playbackController;
  AppShellBottomNavigationVisible? _shellChrome;
  bool _isSeekDragging = false;
  bool _isModalOpen = false;
  bool _isAutoAdvancing = false;
  bool _isPressingPlaybackSurface = false;
  bool _isPageScrolling = false;
  bool _didRecordFirstBuild = false;
  String? _handledEndedItemId;

  String _createSessionKey() {
    return switch (widget.feedMode) {
      PlayerFeedMode.forYou => PlayerPlaybackSessionKeys.forYouTab,
      PlayerFeedMode.singleDrama => PlayerPlaybackSessionKeys.singleDrama(
        dramaId: widget.dramaId,
        episodeId: widget.episodeId,
        instanceId: identityHashCode(this),
      ),
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _sessionKey = _createSessionKey();
    _playbackController = ref.read(
      playerPlaybackControllerProvider(_sessionKey).notifier,
    );
    _playbackController.recordPlaybackTiming(
      'player page init',
      details: [
        'feedMode=${widget.feedMode.name}',
        'hideShellNavigation=${widget.hideShellNavigation}',
        'dramaId=${widget.dramaId ?? 'null'}',
        'episodeId=${widget.episodeId ?? 'null'}',
      ].join(' '),
    );
    _playbackController.recordPlaybackUserAction(
      widget.initialPlaybackTrigger ?? 'player_route_enter',
      trigger: widget.initialPlaybackTrigger ?? 'player_route_enter',
      toItemId: widget.episodeId == null ? null : 'ep-${widget.episodeId}',
      occurredAt: widget.initialUserActionAt,
    );
    if (widget.hideShellNavigation) {
      final shellChrome = ref.read(
        appShellBottomNavigationVisibleProvider.notifier,
      );
      _shellChrome = shellChrome;
    }
    Future<void>.microtask(() {
      _shellChrome?.hide();
      ref
          .read(playerUiControllerProvider(_sessionKey).notifier)
          .startSession(widget.episodeId ?? '1');
      unawaited(_loadFeedForTiming());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 单剧页是独立 route，离开即释放 session；For You 是 shell tab，离开页面实例时
    // 只按可见性暂停，避免 tab provider 和 indexedStack 生命周期冲突。
    if (widget.feedMode == PlayerFeedMode.singleDrama) {
      unawaited(_playbackController.disposeSession(syncState: false));
    } else {
      unawaited(_playbackController.pauseForVisibility(syncState: false));
    }
    _shellChrome?.show();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }
    // 进入后台/非活跃时统一走 visibility pause，释放相邻预热和 prepared window。
    // 不直接 dispose，避免用户回到 app 时 For You tab provider 已被意外清空。
    unawaited(_playbackController.pauseForVisibility());
  }

  @override
  void didHaveMemoryPressure() {
    unawaited(_playbackController.releaseSessionWindow());
  }

  PlayerFeedConfig get _feedConfig {
    return switch (widget.feedMode) {
      PlayerFeedMode.singleDrama => PlayerFeedConfig.singleDrama(
        dramaId: widget.dramaId!,
        episodeId: widget.episodeId!,
      ),
      PlayerFeedMode.forYou => const PlayerFeedConfig.forYou(),
    };
  }

  Future<void> _loadFeedForTiming() async {
    final feedProvider = playerFeedControllerProvider(_sessionKey);
    final feedController = ref.read(feedProvider.notifier);
    final config = _feedConfig;
    final stopwatch = Stopwatch()..start();
    _playbackController.recordPlaybackTiming(
      'feed load start',
      details: [
        'mode=${config.mode.name}',
        'dramaId=${config.dramaId ?? 'null'}',
        'episodeId=${config.episodeId ?? 'null'}',
      ].join(' '),
    );
    await feedController.load(config);
    stopwatch.stop();
    if (!mounted) {
      return;
    }
    final feedState = ref.read(feedProvider);
    _playbackController.recordPlaybackTiming(
      'feed load end',
      itemId: feedState.currentItem?.id,
      elapsed: stopwatch.elapsed,
      error: feedState.error,
      details: [
        'mode=${config.mode.name}',
        'itemCount=${feedState.items.length}',
        'currentIndex=${feedState.currentIndex}',
        'error=${feedState.error != null}',
      ].join(' '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionKey = _sessionKey;
    final feedProvider = playerFeedControllerProvider(sessionKey);
    final uiProvider = playerUiControllerProvider(sessionKey);
    final feedState = ref.watch(feedProvider);
    final feedController = ref.read(feedProvider.notifier);
    final uiState = ref.watch(uiProvider);
    final uiController = ref.read(uiProvider.notifier);
    final playbackProvider = playerPlaybackControllerProvider(sessionKey);
    final playbackState = ref.watch(playbackProvider);
    final playbackController = ref.read(playbackProvider.notifier);
    if (!_didRecordFirstBuild) {
      _didRecordFirstBuild = true;
      playbackController.recordPlaybackTiming(
        'player page first build',
        details: [
          'feedMode=${widget.feedMode.name}',
          'feedLoading=${feedState.isLoading}',
          'itemCount=${feedState.items.length}',
        ].join(' '),
      );
    }

    ref.listen(feedProvider.select((state) => state.currentItem), (
      previous,
      next,
    ) {
      if (next == null || previous?.id == next.id) {
        return;
      }

      ref.read(uiProvider.notifier).selectEpisode(next.episode);
      if (previous != null) {
        final previousIndex = ref
            .read(feedProvider)
            .items
            .indexWhere((item) => item.id == previous.id);
        final nextIndex = ref
            .read(feedProvider)
            .items
            .indexWhere((item) => item.id == next.id);
        final direction = previousIndex == -1
            ? null
            : nextIndex > previousIndex
            ? 'next'
            : 'previous';
        playbackController.recordPlaybackUserAction(
          'PageView page changed',
          trigger: _isAutoAdvancing
              ? 'auto_next'
              : direction == 'previous'
              ? 'swipe_previous'
              : 'swipe_next',
          fromItemId: previous.id,
          toItemId: next.id,
          direction: direction,
          fromIndex: previousIndex,
          toIndex: nextIndex,
        );
      }
      // feed currentItem 是播放链路入口。先 playItem，再按最新 feed/currentIndex 做
      // 相邻 HLS preload 和 next prepare；locked/unavailable 的过滤留给 controller。
      unawaited(() async {
        final playbackNotifier = ref.read(playbackProvider.notifier);
        await playbackNotifier.playItem(next);
        if (!mounted) {
          return;
        }
        await playbackNotifier.preloadAround(
          ref.read(feedProvider).items,
          ref.read(feedProvider).currentIndex,
        );
      }());
    });

    ref.listen(feedProvider.select((state) => state.currentIndex), (
      previous,
      next,
    ) {
      if (!_pageController.hasClients) {
        return;
      }

      final currentPage = _pageController.page?.round();
      if (currentPage != next) {
        _pageController.animateToPage(
          next,
          duration: _isAutoAdvancing
              ? _autoAdvanceDuration
              : _pageTransitionDuration,
          curve: Curves.easeOutCubic,
        );
      }
    });

    ref.listen(playbackProvider, (previous, next) {
      if (!next.hasEnded ||
          previous?.hasEnded == true ||
          next.currentItemId == null ||
          _handledEndedItemId == next.currentItemId ||
          _isSeekDragging ||
          _isModalOpen ||
          uiState.showsPaywall ||
          feedState.currentItem?.id != next.currentItemId) {
        return;
      }

      _handledEndedItemId = next.currentItemId;
      if (feedState.canGoNext) {
        unawaited(_advanceToNextFromCompletion());
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: PopScope(
        canPop: !widget.hideShellNavigation && !uiState.showsPaywall,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }

          if (uiState.showsPaywall) {
            uiController.hidePaywall();
            return;
          }

          if (widget.hideShellNavigation) {
            _exitForYouFeed();
          }
        },
        child: _buildBody(
          feedState,
          feedController,
          uiState,
          uiController,
          playbackState,
          playbackController,
        ),
      ),
    );
  }

  Widget _buildBody(
    PlayerFeedState feedState,
    PlayerFeedController feedController,
    PlayerUiState uiState,
    PlayerUiController uiController,
    PlayerPlaybackState playbackState,
    PlayerPlaybackController playbackController,
  ) {
    if (feedState.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (feedState.error != null) {
      return _PlayerStateMessage(
        icon: Icons.refresh_rounded,
        message: context.l10n.playerFeedLoadFailed,
        actionLabel: context.l10n.retry,
        onAction: feedController.retry,
      );
    }

    if (feedState.items.isEmpty) {
      return _PlayerStateMessage(
        icon: Icons.movie_filter_rounded,
        message: context.l10n.playerFeedEmpty,
      );
    }

    return Stack(
      children: [
        Listener(
          key: const ValueKey('player_page_view_surface'),
          onPointerDown: (_) => _setPlaybackSurfacePressed(true),
          onPointerUp: (_) => _setPlaybackSurfacePressed(false),
          onPointerCancel: (_) => _setPlaybackSurfacePressed(false),
          child: NotificationListener<ScrollNotification>(
            onNotification: _handlePageScrollNotification,
            child: PageView.builder(
              controller: _pageController,
              physics: _isSeekDragging
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              scrollDirection: Axis.vertical,
              itemCount: feedState.items.length,
              onPageChanged: feedController.setCurrentIndex,
              itemBuilder: (context, index) {
                final item = feedState.items[index];
                final isCurrentItem = index == feedState.currentIndex;
                final canRenderVideo =
                    isCurrentItem &&
                    !item.episode.isUnavailable &&
                    !item.episode.isLocked &&
                    playbackState.currentItemId == item.id &&
                    playbackState.currentSource != null;
                final canShowVideoSurface =
                    canRenderVideo && !playbackState.isError;
                final showVideoBeforeFirstFrame =
                    canShowVideoSurface &&
                    !playbackState.hasFirstFrame &&
                    (playbackState.status == PlayerPlaybackStatus.playing ||
                        playbackState.position > Duration.zero);
                final showVideo =
                    canShowVideoSurface &&
                    (playbackState.hasFirstFrame || showVideoBeforeFirstFrame);
                if (showVideoBeforeFirstFrame) {
                  playbackController.recordVideoSurfaceShownBeforeFirstFrame(
                    itemId: item.id,
                    source: playbackState.currentSource,
                  );
                }
                final showLoading =
                    canRenderVideo &&
                    (playbackState.isLoading || showVideoBeforeFirstFrame);
                final showPlaybackError =
                    isCurrentItem && playbackState.isError;
                final canTogglePlayback =
                    canRenderVideo &&
                    (playbackState.status == PlayerPlaybackStatus.playing ||
                        playbackState.status == PlayerPlaybackStatus.paused);
                final showCenterPlayButton =
                    canTogglePlayback &&
                    playbackState.status == PlayerPlaybackStatus.paused &&
                    playbackState.hasFirstFrame &&
                    !playbackState.isBuffering;
                return Stack(
                  children: [
                    PlayerChrome(
                      content: item.content,
                      overlayOpacity: _overlayOpacity,
                      videoController: canRenderVideo
                          ? playbackState.videoController
                          : null,
                      videoFit: _videoFitFor(item.episode),
                      showVideo: showVideo,
                      showLoading: showLoading,
                      playbackError: showPlaybackError,
                      position: playbackState.position,
                      duration: playbackState.duration,
                      bufferedPosition: playbackState.bufferedPosition,
                      seekPreviewPosition: playbackState.seekPreviewPosition,
                      isSeeking: playbackState.isSeeking,
                      showTrackLoading: showLoading && !playbackState.isSeeking,
                      canSeek:
                          playbackState.isSeekAllowed &&
                          !showLoading &&
                          !showPlaybackError &&
                          !item.episode.isUnavailable &&
                          !item.episode.isLocked,
                      onSeekStart: () {
                        setState(() {
                          _isSeekDragging = true;
                        });
                        playbackController.beginSeek();
                      },
                      onSeekUpdate: playbackController.updateSeekPreview,
                      onSeekEnd: () {
                        setState(() {
                          _isSeekDragging = false;
                        });
                        unawaited(playbackController.endSeek());
                      },
                      onSeekCancel: () {
                        setState(() {
                          _isSeekDragging = false;
                        });
                        playbackController.cancelSeek();
                      },
                      onRetry: () {
                        playbackController.recordPlaybackUserAction(
                          'retry tap',
                          trigger: 'retry',
                          fromItemId: playbackState.currentItemId,
                          toItemId: item.id,
                        );
                        unawaited(playbackController.playItem(item));
                      },
                      onDownloadTap:
                          widget.feedMode == PlayerFeedMode.singleDrama
                          ? () {}
                          : null,
                      isPlaying:
                          playbackState.isPlaying &&
                          isCurrentItem &&
                          !item.episode.isUnavailable &&
                          !item.episode.isLocked,
                      showCenterPlayButton: showCenterPlayButton,
                      onTogglePlay: canTogglePlayback
                          ? () {
                              unawaited(playbackController.togglePlay());
                            }
                          : () {},
                      onWatchNowTap:
                          canTogglePlayback &&
                              playbackState.status ==
                                  PlayerPlaybackStatus.paused
                          ? () {
                              unawaited(playbackController.togglePlay());
                            }
                          : () {},
                      onEpisodesTap: () {
                        _showDetailSheet(
                          item.content,
                          initialTab: PlayerDetailTab.episodes,
                        );
                      },
                      onShareTap: _showShareSheet,
                      onMoreTap: () {
                        _showDetailSheet(
                          item.content,
                          initialTab: PlayerDetailTab.synopsis,
                        );
                      },
                      onUnlockTap: uiController.showMemberPaywall,
                      forYouLayout: widget.feedMode == PlayerFeedMode.forYou,
                    ),
                    if (item.episode.isUnavailable)
                      _UnavailableEpisodeOverlay(
                        message: context.l10n.playerEpisodeUnavailable,
                      ),
                    if (widget.feedMode == PlayerFeedMode.singleDrama)
                      _PlayerTopBar(
                        episodeNumber: item.episode.number,
                        playbackRate: playbackState.playbackRate,
                        overlayOpacity: _overlayOpacity,
                        onBackTap: _goBackFromPlayer,
                        onSpeedTap: _showSpeedSheet,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        if (uiState.showsPaywall)
          PlayerPaywallOverlay(
            label: uiState.paywall == PlayerPaywallState.memberUnlock
                ? context.l10n.playerMemberUnlock
                : context.l10n.playerUnlockNow,
            onTap: _showUnlockSheet,
            onDismiss: uiController.hidePaywall,
          ),
      ],
    );
  }

  double get _overlayOpacity => _isPressingPlaybackSurface || _isPageScrolling
      ? _dimmedOverlayOpacity
      : 1.0;

  bool _handlePageScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (notification is ScrollStartNotification) {
        final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
        _playbackController.recordPlaybackUserAction(
          'PageView scroll start',
          trigger: 'page_scroll_start',
          fromItemId: feedState.currentItem?.id,
          fromIndex: feedState.currentIndex,
        );
      }
      _setPageScrolling(true);
      return false;
    }

    if (notification is ScrollEndNotification) {
      _setPageScrolling(false);
    }
    return false;
  }

  void _setPlaybackSurfacePressed(bool isPressed) {
    if (_isPressingPlaybackSurface == isPressed || !mounted) {
      return;
    }
    setState(() {
      _isPressingPlaybackSurface = isPressed;
    });
  }

  void _setPageScrolling(bool isScrolling) {
    if (_isPageScrolling == isScrolling || !mounted) {
      return;
    }
    setState(() {
      _isPageScrolling = isScrolling;
    });
  }

  void _exitForYouFeed() {
    _shellChrome?.show();
    context.go(RoutePaths.home);
  }

  Future<void> _advanceToNextFromCompletion() async {
    if (_isAutoAdvancing || !mounted) {
      return;
    }

    final feedProvider = playerFeedControllerProvider(_sessionKey);
    final feedState = ref.read(feedProvider);
    if (!feedState.canGoNext) {
      return;
    }

    final nextIndex = feedState.currentIndex + 1;
    _isAutoAdvancing = true;
    try {
      _playbackController.recordPlaybackUserAction(
        'auto next animation start',
        trigger: 'auto_next',
        fromItemId: feedState.currentItem?.id,
        toItemId: feedState.items[nextIndex].id,
        direction: 'next',
        fromIndex: feedState.currentIndex,
        toIndex: nextIndex,
      );
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          nextIndex,
          duration: _autoAdvanceDuration,
          curve: Curves.easeOutCubic,
        );
      }

      if (!mounted) {
        return;
      }

      final latestFeedState = ref.read(feedProvider);
      if (latestFeedState.currentIndex != nextIndex) {
        ref.read(feedProvider.notifier).setCurrentIndex(nextIndex);
      }
      _playbackController.recordPlaybackUserAction(
        'auto next animation end',
        trigger: 'auto_next',
        fromItemId: feedState.currentItem?.id,
        toItemId: feedState.items[nextIndex].id,
        direction: 'next',
        fromIndex: feedState.currentIndex,
        toIndex: nextIndex,
      );
    } finally {
      _isAutoAdvancing = false;
    }
  }

  void _goBackFromPlayer() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _closeSheetAndSelectEpisode(
    BuildContext sheetContext,
    PlayerEpisode episode,
  ) {
    Navigator.of(sheetContext).pop();
    if (!mounted) {
      return;
    }

    final targetIndex = ref
        .read(playerFeedControllerProvider(_sessionKey).notifier)
        .selectEpisode(episode);
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .selectEpisode(episode);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _showDetailSheet(
    PlayerContent content, {
    required PlayerDetailTab initialTab,
  }) {
    _isModalOpen = true;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return PlayerDetailSheet(
          content: content,
          initialTab: initialTab,
          currentEpisode:
              ref
                  .read(playerFeedControllerProvider(_sessionKey))
                  .currentItem
                  ?.episode
                  .number ??
              1,
          onEpisodeSelected: (episode) {
            _closeSheetAndSelectEpisode(sheetContext, episode);
          },
        );
      },
    ).whenComplete(() => _isModalOpen = false);
  }

  Future<void> _showShareSheet() {
    _isModalOpen = true;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const PlayerShareSheet(),
    ).whenComplete(() => _isModalOpen = false);
  }

  Future<void> _showSpeedSheet() async {
    _isModalOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return PlayerSpeedSheet(
          selectedRate: ref
              .read(playerPlaybackControllerProvider(_sessionKey))
              .playbackRate,
          onRateSelected: (rate) {
            unawaited(
              ref
                  .read(playerPlaybackControllerProvider(_sessionKey).notifier)
                  .setPlaybackRate(rate),
            );
          },
        );
      },
    );
    _isModalOpen = false;
  }

  Future<void> _showUnlockSheet() async {
    _isModalOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const PlayerUnlockSheet(),
    );
    _isModalOpen = false;

    if (!mounted) {
      return;
    }

    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .unlockPaywallAndPlay();
    unawaited(
      ref
          .read(playerPlaybackControllerProvider(_sessionKey).notifier)
          .playItem(
            ref.read(playerFeedControllerProvider(_sessionKey)).currentItem,
          ),
    );
  }
}

BoxFit _videoFitFor(PlayerEpisode episode) {
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

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.episodeNumber,
    required this.playbackRate,
    required this.overlayOpacity,
    required this.onBackTap,
    required this.onSpeedTap,
  });

  final int episodeNumber;
  final double playbackRate;
  final double overlayOpacity;
  final VoidCallback onBackTap;
  final VoidCallback onSpeedTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      key: const ValueKey('player_top_bar_opacity'),
      opacity: overlayOpacity,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _PlayerPageState._topBarHorizontal,
            _PlayerPageState._topBarTop,
            _PlayerPageState._topBarHorizontal,
            0,
          ),
          child: SizedBox(
            key: const ValueKey('player_single_top_bar'),
            height: _PlayerPageState._topBarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  key: const ValueKey('player_back_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onBackTap,
                  child: const SizedBox.square(
                    dimension: _PlayerPageState._topBarHeight,
                    child: Center(
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: _PlayerPageState._topBarBackIconSize,
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
                  size: _PlayerPageState._topBarMoreIconSize,
                ),
              ],
            ),
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

class _PlayerStateMessage extends StatelessWidget {
  const _PlayerStateMessage({
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

class _UnavailableEpisodeOverlay extends StatelessWidget {
  const _UnavailableEpisodeOverlay({required this.message});

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
