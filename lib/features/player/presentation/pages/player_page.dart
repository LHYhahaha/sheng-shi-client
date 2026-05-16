import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../../entitlement/domain/episode_access_decision.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_feed_engine.dart';
import '../../application/player_overlay_orchestrator.dart';
import '../../application/player_performance_policy_provider.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../application/player_rebuild_diagnostics.dart';
import '../../application/player_runtime_coordinator.dart';
import '../../application/player_ui_controller.dart';
import '../../application/player_viewport_controller.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/player_performance_policy.dart';
import '../../domain/player_content.dart';
import '../../domain/player_feed.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_detail_sheet.dart';
import '../widgets/player_feed_page_shell.dart';
import '../widgets/player_playback_layer.dart';
import '../widgets/player_recharge_unlock_sheet.dart';

/// 播放器页面：纵向 [PageView] feed + 顶层单例视频 surface。
///
/// 手势与落位由 [PlayerViewportController] 管理；权益/播放/预加载仅在 settled 后由
/// [PlayerRuntimeCoordinator] 执行；自动解锁弹窗由 [PlayerOverlayOrchestrator] 调度。
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
  static const _dimmedOverlayOpacity = 0.64;

  late final PageController _pageController;
  late final String _sessionKey;
  late final PlayerPlaybackController _playbackController;
  late final PlayerOverlayOrchestrator _overlayOrchestrator;
  AppShellBottomNavigationVisible? _shellChrome;
  bool _isSeekDragging = false;
  bool _isModalOpen = false;
  bool _isAutoAdvancing = false;
  bool _isPressingPlaybackSurface = false;
  bool _isPageScrolling = false;
  bool _didRecordFirstBuild = false;
  String? _activeCoinSheetItemId;
  String? _activeRechargeSheetItemId;
  final ValueNotifier<double> _overlayOpacityNotifier = ValueNotifier<double>(
    1.0,
  );
  final ValueNotifier<double> _pagePositionNotifier = ValueNotifier<double>(
    0.0,
  );

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
    _pageController.addListener(_syncActiveVideoPagePosition);
    _sessionKey = _createSessionKey();
    _playbackController = ref.read(
      playerPlaybackControllerProvider(_sessionKey).notifier,
    );
    _overlayOrchestrator = ref.read(
      playerOverlayOrchestratorProvider(_sessionKey).notifier,
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
      _shellChrome = ref.read(appShellBottomNavigationVisibleProvider.notifier);
    }
    Future<void>.microtask(() async {
      _shellChrome?.hide();
      await ref.read(entitlementControllerProvider.notifier).load();
      if (!mounted) {
        return;
      }
      ref
          .read(playerUiControllerProvider(_sessionKey).notifier)
          .startSession(widget.episodeId ?? '1');
      unawaited(_loadFeedForTiming());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayOrchestrator.cancelPending();
    _playbackController.detachVideoSurfaceForTeardown();
    unawaited(
      _playbackController.disposeSession(
        syncState: false,
        disposeDelay: PlayerPlaybackController.shouldDelayVideoSurfaceTeardown
            ? PlayerPlaybackController.videoSurfaceTeardownDelay
            : Duration.zero,
      ),
    );
    _shellChrome?.show();
    _overlayOpacityNotifier.dispose();
    _pageController.removeListener(_syncActiveVideoPagePosition);
    _pagePositionNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      return;
    }
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
    if (feedState.currentItem != null) {
      ref
          .read(playerViewportControllerProvider(_sessionKey).notifier)
          .initialize(
            index: feedState.currentIndex,
            itemId: feedState.currentItem!.id,
          );
      if (_pageController.hasClients &&
          feedState.currentIndex != _pageController.page?.round()) {
        _pageController.jumpToPage(feedState.currentIndex);
      }
    }
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
    final viewportProvider = playerViewportControllerProvider(sessionKey);
    final engineProvider = playerFeedEngineProvider(sessionKey);
    final runtimeProvider = playerRuntimeCoordinatorProvider(sessionKey);
    final overlayProvider = playerOverlayOrchestratorProvider(sessionKey);
    final performancePolicy = ref.watch(playerPerformancePolicyProvider);

    final feedSnapshot = ref.watch(
      feedProvider.select(
        (state) => (
          state.isLoading,
          state.error,
          state.items,
          state.currentIndex,
          state.canGoNext,
        ),
      ),
    );
    final showsPaywall = ref.watch(
      uiProvider.select((state) => state.showsPaywall),
    );
    final viewportState = ref.watch(
      viewportProvider.select(PlayerViewportBuildSnapshot.fromState),
    );
    final playbackShell = ref.watch(
      playerPlaybackControllerProvider(
        sessionKey,
      ).select(PlayerPlaybackShellSnapshot.fromState),
    );

    final feedState = ref.read(feedProvider);
    final feedController = ref.read(feedProvider.notifier);
    final feedEngine = ref.read(engineProvider.notifier);
    final runtimeController = ref.read(runtimeProvider.notifier);
    final uiController = ref.read(uiProvider.notifier);
    final playbackController = ref.read(
      playerPlaybackControllerProvider(sessionKey).notifier,
    );

    PlayerRebuildDiagnostics.recordPlayerPageBuild(
      sessionKey: sessionKey,
      itemId: feedState.currentItem?.id,
    );
    if (!_didRecordFirstBuild) {
      _didRecordFirstBuild = true;
      playbackController.recordPlaybackTiming(
        'player page first build',
        details: [
          'feedMode=${widget.feedMode.name}',
          'feedLoading=${feedSnapshot.$1}',
          'itemCount=${feedSnapshot.$3.length}',
        ].join(' '),
      );
    }

    ref.listen(
      viewportProvider.select(PlayerViewportSettledSnapshot.fromState),
      (previous, next) {
        if (next.itemId == null ||
            (previous?.itemId == next.itemId &&
                previous?.generation == next.generation)) {
          return;
        }
        final latestFeedState = ref.read(feedProvider);
        if (next.index < 0 || next.index >= latestFeedState.items.length) {
          return;
        }
        final settledItem = latestFeedState.items[next.index];
        if (settledItem.id != next.itemId) {
          return;
        }
        unawaited(
          feedEngine.onViewportSettled(
            item: settledItem,
            index: next.index,
            previousItemId: previous?.itemId,
            previousIndex: previous?.index,
            playbackTrigger: _isAutoAdvancing
                ? 'auto_next'
                : previous != null && next.index > previous.index
                ? 'swipe_next'
                : 'swipe_previous',
            isModalOpen: _isModalOpen,
            hasActiveCoinSheet: _activeCoinSheetItemId != null,
            hasActiveRechargeSheet: _activeRechargeSheetItemId != null,
            isPageScrolling: _isPageScrolling,
            isCurrentFeedItem: runtimeController.isCurrentFeedItem,
            isPageActivelyMoving: _isPageActivelyMovingForAutoSheet,
          ),
        );
      },
    );

    ref.listen(
      overlayProvider.select((state) => state.pendingAutoSheetItemId),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        PlayerFeedItem? settledItem;
        for (final candidate in ref.read(feedProvider).items) {
          if (candidate.id == next) {
            settledItem = candidate;
            break;
          }
        }
        if (settledItem == null || !mounted) {
          return;
        }
        ref.read(overlayProvider.notifier).clearPendingSheetRequest();
        unawaited(_presentAutoUnlockSheetForItem(settledItem));
      },
    );

    ref.listen(feedProvider.select((state) => state.currentIndex), (
      previous,
      next,
    ) {
      if (!_pageController.hasClients) {
        return;
      }
      final currentPage = _pageController.page?.round();
      if (currentPage != next) {
        unawaited(() async {
          await _pageController.animateToPage(
            next,
            duration: _isAutoAdvancing
                ? _autoAdvanceDuration
                : _pageTransitionDuration,
            curve: Curves.easeOutCubic,
          );
          if (!mounted) {
            return;
          }
          _settleViewportAtIndex(next);
        }());
        return;
      }
      _settleViewportAtIndex(next);
    });

    ref.listen(
      playerPlaybackControllerProvider(
        sessionKey,
      ).select((state) => (state.currentItemId, state.hasEnded)),
      (previous, next) {
        if (!feedEngine.shouldHandlePlaybackEnded(
          currentItemId: next.$1,
          hasEnded: next.$2,
          isSeekDragging: _isSeekDragging,
          isModalOpen: _isModalOpen,
          showsPaywall: showsPaywall,
        )) {
          return;
        }
        feedEngine.markEndedHandled(next.$1!);
        if (feedSnapshot.$5) {
          unawaited(_advanceToNextFromCompletion());
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: PopScope(
        canPop:
            widget.feedMode == PlayerFeedMode.forYou &&
            !widget.hideShellNavigation &&
            !showsPaywall,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          if (showsPaywall) {
            uiController.hidePaywall();
            return;
          }
          if (widget.hideShellNavigation) {
            _exitForYouFeed();
            return;
          }
          if (widget.feedMode == PlayerFeedMode.singleDrama) {
            unawaited(_goBackFromPlayer());
          }
        },
        child: _buildBody(
          isLoading: feedSnapshot.$1,
          error: feedSnapshot.$2,
          items: feedSnapshot.$3,
          feedController: feedController,
          viewportState: viewportState,
          playbackShell: playbackShell,
          playbackController: playbackController,
          runtimeController: runtimeController,
          feedEngine: ref.read(engineProvider.notifier),
          performancePolicy: performancePolicy,
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool isLoading,
    required Object? error,
    required List<PlayerFeedItem> items,
    required PlayerFeedController feedController,
    required PlayerViewportBuildSnapshot viewportState,
    required PlayerPlaybackShellSnapshot playbackShell,
    required PlayerPlaybackController playbackController,
    required PlayerRuntimeCoordinator runtimeController,
    required PlayerFeedEngine feedEngine,
    required PlayerPerformancePolicy performancePolicy,
  }) {
    if (isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (error != null) {
      return PlayerStateMessage(
        icon: Icons.refresh_rounded,
        message: context.l10n.playerFeedLoadFailed,
        actionLabel: context.l10n.retry,
        onAction: feedController.retry,
      );
    }
    if (items.isEmpty) {
      return PlayerStateMessage(
        icon: Icons.movie_filter_rounded,
        message: context.l10n.playerFeedEmpty,
      );
    }

    final settledIndex = viewportState.settledIndex;
    final settledItem = settledIndex >= 0 && settledIndex < items.length
        ? items[settledIndex]
        : null;
    final isViewportDragging =
        viewportState.scrollPhase == PlayerViewportScrollPhase.dragging;
    final accessForSettled = settledItem == null
        ? null
        : feedEngine.accessPresentationFor(settledItem);
    final canShowActiveVideoOverlay =
        settledItem != null &&
        accessForSettled == PlayerAccessPresentationState.playable;
    final activeVideoItemId = playbackShell.currentItemId ?? settledItem?.id;
    final activeVideoIndex = activeVideoItemId == null
        ? settledIndex
        : items.indexWhere((candidate) => candidate.id == activeVideoItemId);

    return Stack(
      children: [
        ActivePlaybackSurfaceOverlay(
          sessionKey: _sessionKey,
          itemId: activeVideoItemId,
          currentIndex: activeVideoIndex == -1
              ? settledIndex
              : activeVideoIndex,
          pagePositionListenable: _pagePositionNotifier,
          canShowVideo: canShowActiveVideoOverlay,
          policy: performancePolicy,
          isViewportDragging: isViewportDragging,
          videoFit: settledItem == null
              ? BoxFit.cover
              : videoFitForEpisode(settledItem.episode),
          forYouLayout: widget.feedMode == PlayerFeedMode.forYou,
        ),
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
              itemCount: items.length,
              onPageChanged: feedEngine.onPageChanged,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSettledPage = index == viewportState.settledIndex;
                PlayerRebuildDiagnostics.recordPageViewItemBuild(
                  itemId: item.id,
                  isCurrent: isSettledPage,
                );
                return PlayerFeedPageShell(
                  key: ValueKey('player_feed_page_${item.id}'),
                  sessionKey: _sessionKey,
                  item: item,
                  index: index,
                  isSettledPage: isSettledPage,
                  forYouLayout: widget.feedMode == PlayerFeedMode.forYou,
                  allowPressChromeDimming:
                      performancePolicy.allowPressChromeDimming,
                  overlayOpacityListenable:
                      performancePolicy.allowPressChromeDimming
                      ? _overlayOpacityNotifier
                      : null,
                  onTogglePlay: () {
                    unawaited(playbackController.togglePlay());
                  },
                  onRetry: () {
                    unawaited(_retryPlaybackForItem(item));
                  },
                  onSeekStart: () {
                    _setSeekDragging(true);
                    playbackController.beginSeek();
                  },
                  onSeekUpdate: playbackController.updateSeekPreview,
                  onSeekEnd: () {
                    _setSeekDragging(false);
                    unawaited(playbackController.endSeek());
                  },
                  onSeekCancel: () {
                    _setSeekDragging(false);
                    playbackController.cancelSeek();
                  },
                  onWatchNowTap: () {
                    unawaited(playbackController.togglePlay());
                  },
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
                  onUnlockTap: () {
                    unawaited(_showPendingUnlockActionSheet());
                  },
                  onOpenMembership: _openMembership,
                  onDownloadTap: widget.feedMode == PlayerFeedMode.singleDrama
                      ? () {}
                      : null,
                );
              },
            ),
          ),
        ),
        if (widget.feedMode == PlayerFeedMode.singleDrama &&
            settledItem != null)
          PlayerTopBar(
            episodeNumber: settledItem.episode.number,
            playbackRate: playbackShell.playbackRate,
            overlayOpacity: 1,
            overlayOpacityListenable: performancePolicy.allowPressChromeDimming
                ? _overlayOpacityNotifier
                : null,
            onBackTap: () {
              unawaited(_goBackFromPlayer());
            },
            onSpeedTap: _showSpeedSheet,
          ),
      ],
    );
  }

  void _syncOverlayOpacity() {
    final policy = ref.read(playerPerformancePolicyProvider);
    if (!policy.allowPressChromeDimming) {
      if (_overlayOpacityNotifier.value != 1.0) {
        _overlayOpacityNotifier.value = 1.0;
      }
      return;
    }
    final next = _isPressingPlaybackSurface || _isPageScrolling
        ? _dimmedOverlayOpacity
        : 1.0;
    if (_overlayOpacityNotifier.value == next) {
      return;
    }
    _overlayOpacityNotifier.value = next;
  }

  void _settleViewportAtIndex(int index) {
    final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    if (index < 0 || index >= feedState.items.length) {
      return;
    }
    ref
        .read(playerViewportControllerProvider(_sessionKey).notifier)
        .settle(index: index, itemId: feedState.items[index].id);
  }

  void _syncActiveVideoPagePosition() {
    if (!_pageController.hasClients) {
      return;
    }
    final page = _pageController.page ?? _pageController.initialPage.toDouble();
    if ((_pagePositionNotifier.value - page).abs() < 0.001) {
      return;
    }
    _pagePositionNotifier.value = page;
  }

  bool _handlePageScrollNotification(ScrollNotification notification) {
    final feedEngine = ref.read(playerFeedEngineProvider(_sessionKey).notifier);
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (notification is ScrollStartNotification) {
        feedEngine.onScrollStart();
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
      final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
      feedEngine.onScrollEnd();
      if (feedState.items.isNotEmpty) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) {
            return;
          }
          final page = _pageController.page;
          if (page == null) {
            return;
          }
          final settledIndex = page.round().clamp(
            0,
            feedState.items.length - 1,
          );
          final settledItem = feedState.items[settledIndex];
          feedEngine.settleViewport(
            index: settledIndex,
            itemId: settledItem.id,
          );
        });
      }
    }
    return false;
  }

  void _setPlaybackSurfacePressed(bool isPressed) {
    if (_isPressingPlaybackSurface == isPressed) {
      return;
    }
    _isPressingPlaybackSurface = isPressed;
    _syncOverlayOpacity();
  }

  void _setPageScrolling(bool isScrolling) {
    if (_isPageScrolling == isScrolling) {
      return;
    }
    _isPageScrolling = isScrolling;
    _syncOverlayOpacity();
  }

  void _setSeekDragging(bool isDragging) {
    if (_isSeekDragging == isDragging || !mounted) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {
        _isSeekDragging = isDragging;
      });
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSeekDragging == isDragging) {
        return;
      }
      setState(() {
        _isSeekDragging = isDragging;
      });
    });
  }

  bool _isPageActivelyMovingForAutoSheet(PlayerFeedItem item) {
    if (!_isPageScrolling) {
      return false;
    }
    if (!_pageController.hasClients) {
      return true;
    }
    final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    final itemIndex = feedState.items.indexWhere(
      (candidate) => candidate.id == item.id,
    );
    final page = _pageController.page;
    if (itemIndex == -1 || page == null) {
      return true;
    }
    return (page - itemIndex).abs() > 0.01;
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
      ref.read(feedProvider.notifier).setCurrentIndex(nextIndex);
      ref
          .read(playerViewportControllerProvider(_sessionKey).notifier)
          .settle(index: nextIndex, itemId: feedState.items[nextIndex].id);
    } finally {
      _isAutoAdvancing = false;
    }
  }

  Future<void> _goBackFromPlayer() async {
    await _playbackController.detachSurfaceForDispose();
    await WidgetsBinding.instance.endOfFrame;
    _playbackController.markSurfaceDetached();
    if (PlayerPlaybackController.shouldDelayVideoSurfaceTeardown) {
      await Future<void>.delayed(
        PlayerPlaybackController.videoSurfaceTeardownDelay,
      );
    }
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }

  Future<void> _retryPlaybackForItem(PlayerFeedItem item) async {
    final runtime = ref.read(
      playerRuntimeCoordinatorProvider(_sessionKey).notifier,
    );
    final decision = ref
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: item.content.id,
          episodeId: item.episode.id,
          itemId: item.id,
          unlockType: item.episode.unlockType,
          price: item.episode.requiredCoins,
          isUnavailable: item.episode.isUnavailable,
        );
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        await runtime.handleAccessDecision(
          item,
          decision,
          autoPresentSheet: false,
        );
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        await runtime.handleAccessDecision(
          item,
          decision,
          autoPresentSheet: false,
        );
        if (mounted && runtime.isCurrentFeedItem(item)) {
          await _showCoinUnlockSheetForItem(item);
        }
      case EpisodeAccessDecisionType.showRechargeDialog:
        await runtime.handleAccessDecision(
          item,
          decision,
          autoPresentSheet: false,
        );
        if (mounted && runtime.isCurrentFeedItem(item)) {
          await _showRechargeUnlockSheetForItem(item);
        }
      case EpisodeAccessDecisionType.goMembership:
        await runtime.handleAccessDecision(
          item,
          decision,
          autoPresentSheet: false,
        );
      case EpisodeAccessDecisionType.waitUnlock:
        await runtime.handleAccessDecision(
          item,
          decision,
          autoPresentSheet: false,
        );
    }
  }

  Future<void> _presentAutoUnlockSheetForItem(PlayerFeedItem item) async {
    final runtime = ref.read(
      playerRuntimeCoordinatorProvider(_sessionKey).notifier,
    );
    if (!runtime.isCurrentFeedItem(item) ||
        _isModalOpen ||
        _activeCoinSheetItemId != null ||
        _activeRechargeSheetItemId != null) {
      return;
    }
    final presenter = ref
        .read(playerRuntimeCoordinatorProvider(_sessionKey))
        .accessPresenter;
    if (!presenter.isLockedAutoSheetCandidate(item)) {
      return;
    }
    final decision = ref
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: item.content.id,
          episodeId: item.episode.id,
          itemId: item.id,
          unlockType: item.episode.unlockType,
          price: item.episode.requiredCoins,
          isUnavailable: item.episode.isUnavailable,
        );
    if (!mounted || !runtime.isCurrentFeedItem(item)) {
      return;
    }
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        await runtime.handleAccessDecision(
          item,
          decision,
          autoPresentSheet: false,
        );
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        await _showCoinUnlockSheetForItem(item, launchedByAutoSheet: true);
      case EpisodeAccessDecisionType.showRechargeDialog:
        await _showRechargeUnlockSheetForItem(item, launchedByAutoSheet: true);
      case EpisodeAccessDecisionType.goMembership:
      case EpisodeAccessDecisionType.waitUnlock:
        return;
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
    _settleViewportAtIndex(targetIndex);
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

  Future<void> _showPendingUnlockActionSheet() async {
    ref
        .read(playerOverlayOrchestratorProvider(_sessionKey).notifier)
        .cancelPending();
    if (_isModalOpen) {
      return;
    }
    final currentItem = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    final runtime = ref.read(
      playerRuntimeCoordinatorProvider(_sessionKey).notifier,
    );
    if (currentItem == null ||
        !runtime.isCurrentFeedItem(currentItem) ||
        !ref
            .read(playerRuntimeCoordinatorProvider(_sessionKey))
            .accessPresenter
            .isLockedAutoSheetCandidate(currentItem)) {
      return;
    }
    final decision = ref
        .read(entitlementControllerProvider.notifier)
        .evaluateAccess(
          dramaId: currentItem.content.id,
          episodeId: currentItem.episode.id,
          itemId: currentItem.id,
          unlockType: currentItem.episode.unlockType,
          price: currentItem.episode.requiredCoins,
          isUnavailable: currentItem.episode.isUnavailable,
        );
    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        await runtime.handleAccessDecision(
          currentItem,
          decision,
          autoPresentSheet: false,
        );
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        await _showCoinUnlockSheetForItem(currentItem);
      case EpisodeAccessDecisionType.showRechargeDialog:
        await _showRechargeUnlockSheetForItem(currentItem);
      case EpisodeAccessDecisionType.goMembership:
        _openMembership();
      case EpisodeAccessDecisionType.waitUnlock:
        if (!currentItem.episode.isUnavailable) {
          await _showRechargeUnlockSheetForItem(currentItem);
        }
    }
  }

  Future<void> _showCoinUnlockSheetForItem(
    PlayerFeedItem item, {
    bool launchedByAutoSheet = false,
  }) async {
    if (_activeCoinSheetItemId == item.id) {
      return;
    }
    _activeCoinSheetItemId = item.id;
    _isModalOpen = true;
    final balance = ref.read(entitlementControllerProvider).coinBalance;
    final unlocked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return PlayerCoinUnlockSheet(
          price: item.episode.requiredCoins,
          balance: balance,
          onConfirm: () => Navigator.of(sheetContext).pop(true),
        );
      },
    );
    _isModalOpen = false;
    _activeCoinSheetItemId = null;
    if (unlocked != true && launchedByAutoSheet) {
      ref
          .read(playerOverlayOrchestratorProvider(_sessionKey).notifier)
          .markDismissed(item.id);
    }
    if (!mounted || unlocked != true) {
      return;
    }
    final runtime = ref.read(
      playerRuntimeCoordinatorProvider(_sessionKey).notifier,
    );
    if (!runtime.isCurrentFeedItem(item)) {
      return;
    }
    final decision = await ref
        .read(entitlementControllerProvider.notifier)
        .unlockWithCoins(
          dramaId: item.content.id,
          episodeId: item.episode.id,
          itemId: item.id,
          price: item.episode.requiredCoins,
          operationId: 'coin-unlock:${item.content.id}:${item.episode.id}',
        );
    if (!mounted) {
      return;
    }
    await runtime.handleAccessDecision(item, decision, autoPresentSheet: false);
  }

  Future<void> _showRechargeUnlockSheetForItem(
    PlayerFeedItem item, {
    bool launchedByAutoSheet = false,
  }) async {
    if (_activeRechargeSheetItemId == item.id) {
      return;
    }
    _activeRechargeSheetItemId = item.id;
    _isModalOpen = true;
    final rechargeController = ref.read(
      playerRechargeUnlockControllerProvider(_sessionKey).notifier,
    );
    await rechargeController.open(
      itemId: item.id,
      requiredCoins: item.episode.requiredCoins,
    );
    if (!mounted) {
      return;
    }
    final unlocked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      builder: (context) => PlayerRechargeUnlockSheet(sessionKey: _sessionKey),
    );
    _isModalOpen = false;
    _activeRechargeSheetItemId = null;
    if (!mounted) {
      return;
    }
    if (unlocked != true) {
      if (launchedByAutoSheet) {
        ref
            .read(playerOverlayOrchestratorProvider(_sessionKey).notifier)
            .markDismissed(item.id);
      }
      rechargeController.close();
      return;
    }
    final rechargeState = ref.read(
      playerRechargeUnlockControllerProvider(_sessionKey),
    );
    final selectedCoinPackage = rechargeState.selectedCoinPackage;
    final selectedMembershipPackage = rechargeState.selectedMembershipPackage;
    final entitlementController = ref.read(
      entitlementControllerProvider.notifier,
    );
    if (selectedCoinPackage != null) {
      await entitlementController.grantMockCoins(
        amount: selectedCoinPackage.totalCoins,
        source: 'player_recharge_unlock_sheet',
      );
    } else if (selectedMembershipPackage != null) {
      await entitlementController.grantMockMembership(
        source: 'player_recharge_unlock_sheet',
      );
    }
    if (!mounted) {
      return;
    }
    rechargeController.close();
    final runtime = ref.read(
      playerRuntimeCoordinatorProvider(_sessionKey).notifier,
    );
    if (!runtime.isCurrentFeedItem(item)) {
      return;
    }
    await runtime.quiesceAfterRecharge(
      item,
      reason: selectedMembershipPackage == null
          ? 'recharge success awaiting coin confirmation'
          : 'membership purchase success awaiting user action',
    );
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .showUnlockPaywall();
    if (selectedCoinPackage != null) {
      unawaited(
        _showCoinUnlockSheetForItem(
          item,
          launchedByAutoSheet: launchedByAutoSheet,
        ),
      );
    }
  }

  void _openMembership() {
    context.push(RoutePaths.membership);
  }
}
