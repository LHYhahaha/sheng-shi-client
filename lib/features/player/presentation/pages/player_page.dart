import 'dart:developer' as developer;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_feed_engine.dart';
import '../../application/player_feed_engine_access_flow.dart';
import '../../application/player_like_controller.dart';
import '../../application/player_overlay_orchestrator.dart';
import '../../application/player_performance_policy_provider.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_unlock_modal_coordinator.dart';
import '../../application/player_rebuild_diagnostics.dart';
import '../../application/player_ui_controller.dart';
import '../../application/player_viewport_controller.dart';
import '../../application/watch_progress_provider.dart';
import '../../data/player_content_repository_provider.dart';
import '../../data/player_remote_data_source_provider.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/player_performance_policy.dart';
import '../../domain/player_content.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_playback_progress.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_detail_sheet.dart';
import '../widgets/player_feed_page_shell.dart';
import '../widgets/player_playback_layer.dart';

/// 播放器 UI 宿主：纵向 [PageView] + 顶层单例 Video surface + sheet。
///
/// 职责边界：
/// - 本文件：布局、手势转发、局部 sheet（详情/分享/倍速）、解锁弹窗委托 AppModal。
/// - [PlayerFeedEngine]：viewport settled、权益/播放/预加载/弹窗调度（不在 drag 路径调用）。
/// - [PlayerPlaybackController]：media_kit 真实状态（position/play/source），不含 sheet 业务。
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
  late final AppModalService _modalService;
  AppShellBottomNavigationVisible? _shellChrome;
  PlaybackProgress? _resumeProgress;
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

  PlayerFeedEngine get _feedEngine =>
      ref.read(playerFeedEngineProvider(_sessionKey).notifier);

  PlayerUnlockModalCoordinator get _unlockModalCoordinator =>
      ref.read(playerUnlockModalCoordinatorProvider(_sessionKey));

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
    _modalService = ref.read(appModalServiceProvider);
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
      // await ref.read(entitlementControllerProvider.notifier).load();
      if (!mounted) {
        return;
      }
      
      // 从 watch progress API 获取观看进度（所有进入播放页的场景都需要检查是否有之前的进度）
      if (widget.dramaId != null) {
        try {
          final dramaId = int.tryParse(widget.dramaId!);
          if (dramaId != null) {
            developer.log('PlayerPage: 准备获取 watch progress，dramaId=$dramaId');
            final dataSource = ref.read(playerRemoteDataSourceProvider);
            final watchProgress = await dataSource.fetchWatchProgress(
              dramaId: dramaId,
            );
            developer.log('PlayerPage: 获取到 watch progress=$watchProgress');
            if (watchProgress != null && mounted) {
              // 构建与 PlayerFeedItem 一致的 id 格式：'single:{content.id}:{episode.id}'
              final contentId = widget.dramaId;
              final episodeId = watchProgress.episodeId.toString();
              _resumeProgress = PlaybackProgress(
                itemId: 'single:$contentId:$episodeId',
                position: Duration(seconds: watchProgress.watchSecond),
                duration: Duration(seconds: watchProgress.durationSecond),
                updatedAt: DateTime.now(),
              );
              developer.log(
                'PlayerPage: _resumeProgress 已设置：'
                'itemId=${_resumeProgress!.itemId}, '
                'position=${_resumeProgress!.position.inSeconds}s, '
                'duration=${_resumeProgress!.duration.inSeconds}s, '
                'canResume=${_resumeProgress!.canResume}',
              );
              developer.log(
                'Loaded watch progress: itemId=${_resumeProgress!.itemId}, '
                'position=${_resumeProgress!.position.inSeconds}s, '
                'trigger=${widget.initialPlaybackTrigger}',
              );
              // 立即设置待恢复的播放进度，避免播放已开始才设置
              _playbackController.setPendingResumeProgress(_resumeProgress);
            }
          }
        } catch (e) {
          developer.log('Failed to fetch watch progress: $e', error: e);
        }
      }
      
      if (!mounted) {
        return;
      }
      
      final uiController = ref.read(
        playerUiControllerProvider(_sessionKey).notifier,
      );
      uiController.startSession(widget.episodeId ?? '1');
      uiController.configureAutoImmersiveSession(
        enabled: widget.feedMode == PlayerFeedMode.singleDrama,
      );
      if (widget.feedMode == PlayerFeedMode.singleDrama) {
        _syncAutoImmersiveBlockers();
      }
      
      // 每次进入播放页时，刷新点赞状态
      if (widget.dramaId != null) {
        final likeController = ref.read(
          playerLikeControllerProvider(widget.dramaId!).notifier,
        );
        unawaited(likeController.refreshLikeStatus());
      }
      
      await _loadFeedForTiming();
    });
  }

  @override
  void dispose() {
    // 上报观看退出事件
    unawaited(_playbackController.reportWatchProgress(eventType: 4)); // 4: exit
    WidgetsBinding.instance.removeObserver(this);
    _modalService.dismissForSource(AppModalSource.player);
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
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .onRouteVisibilityChanged(state == AppLifecycleState.resumed);
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
      // 设置待恢复的播放进度（从播放历史进入时）
      if (_resumeProgress != null) {
        _playbackController.setPendingResumeProgress(_resumeProgress);
      }
      
      _feedEngine.initializeViewport(
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
    if (widget.feedMode == PlayerFeedMode.singleDrama) {
      _syncAutoImmersiveBlockers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionKey = _sessionKey;
    ref.watch(playerUnlockModalCoordinatorProvider(sessionKey));
    final feedProvider = playerFeedControllerProvider(sessionKey);
    final uiProvider = playerUiControllerProvider(sessionKey);
    final viewportProvider = playerViewportControllerProvider(sessionKey);
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
    final showsChromeOverlays = ref.watch(
      uiProvider.select((state) => state.showsChromeOverlays),
    );
    final chromeOverlayFadeDuration = performancePolicy.allowRichTransitions
        ? const Duration(milliseconds: 200)
        : Duration.zero;
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
    final feedEngine = _feedEngine;
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
        final accessPlayable =
            feedEngine.accessPresentationFor(settledItem) ==
            PlayerAccessPresentationState.playable;
        final isItemChange =
            previous?.itemId != null && previous!.itemId != next.itemId;
        uiController.onViewportSettled(
          accessPlayable: accessPlayable,
          isItemChange: isItemChange,
        );
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
            isCurrentFeedItem: feedEngine.isCurrentFeedItem,
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

    // Defer：feed 编程切页仍直接驱动 PageController（非用户 drag），见 _closeSheetAndSelectEpisode。
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

    if (widget.feedMode == PlayerFeedMode.singleDrama) {
      ref.listen(
        playerPlaybackControllerProvider(
          sessionKey,
        ).select((state) => state.isPlaying),
        (previous, next) {
          _syncAutoImmersiveBlockers();
        },
      );
      ref.listen(viewportProvider.select((state) => state.scrollPhase), (
        previous,
        next,
      ) {
        _syncAutoImmersiveBlockers(
          isViewportDragging: next != PlayerViewportScrollPhase.idle,
        );
      });
    }

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
        // 上报观看完成事件
        unawaited(playbackController.reportWatchProgress(eventType: 6)); // 6: complete
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
          feedEngine: feedEngine,
          performancePolicy: performancePolicy,
          showsChromeOverlays: showsChromeOverlays,
          chromeOverlayFadeDuration: chromeOverlayFadeDuration,
          uiController: uiController,
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
    required PlayerFeedEngine feedEngine,
    required PlayerPerformancePolicy performancePolicy,
    required bool showsChromeOverlays,
    required Duration chromeOverlayFadeDuration,
    required PlayerUiController uiController,
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
                    if (widget.feedMode == PlayerFeedMode.singleDrama) {
                      uiController.notifyUserInteraction();
                    }
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
                  showChromeOverlays: widget.feedMode == PlayerFeedMode.forYou
                      ? true
                      : showsChromeOverlays,
                  chromeOverlayFadeDuration: chromeOverlayFadeDuration,
                  useSingleDramaChromeTap:
                      widget.feedMode == PlayerFeedMode.singleDrama,
                  onExitImmersiveChrome:
                      widget.feedMode == PlayerFeedMode.singleDrama
                      ? uiController.onImmersiveVideoTap
                      : null,
                  onSingleDramaUserInteraction:
                      widget.feedMode == PlayerFeedMode.singleDrama
                      ? uiController.notifyUserInteraction
                      : null,
                );
              },
            ),
          ),
        ),
        if (widget.feedMode == PlayerFeedMode.singleDrama &&
            settledItem != null)
          AnimatedOpacity(
            key: const ValueKey('player_top_bar_chrome_visibility'),
            opacity: showsChromeOverlays ? 1 : 0,
            duration: chromeOverlayFadeDuration,
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !showsChromeOverlays,
              child: PlayerTopBar(
                episodeNumber: settledItem.episode.number,
                playbackRate: playbackShell.playbackRate,
                overlayOpacity: 1,
                overlayOpacityListenable:
                    performancePolicy.allowPressChromeDimming
                    ? _overlayOpacityNotifier
                    : null,
                onBackTap: () {
                  unawaited(_goBackFromPlayer());
                },
                onSpeedTap: _showSpeedSheet,
              ),
            ),
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
    _feedEngine.settleViewport(index: index, itemId: feedState.items[index].id);
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
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (notification is ScrollStartNotification) {
        _feedEngine.onScrollStart();
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
      _feedEngine.onScrollEnd();
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
          _feedEngine.settleViewport(
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
    _syncAutoImmersiveBlockers();
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
      _syncAutoImmersiveBlockers();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSeekDragging == isDragging) {
        return;
      }
      setState(() {
        _isSeekDragging = isDragging;
      });
      _syncAutoImmersiveBlockers();
    });
  }

  void _syncAutoImmersiveBlockers({bool? isViewportDragging}) {
    if (widget.feedMode != PlayerFeedMode.singleDrama) {
      return;
    }
    final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    final item = feedState.currentItem;
    final accessPlayable =
        item != null &&
        _feedEngine.accessPresentationFor(item) ==
            PlayerAccessPresentationState.playable;
    final playback = ref.read(playerPlaybackControllerProvider(_sessionKey));
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .syncAutoImmersiveBlockers(
          playbackIsPlaying: playback.isPlaying,
          accessPlayable: accessPlayable,
          modalBlocking:
              _isModalOpen ||
              _activeCoinSheetItemId != null ||
              _activeRechargeSheetItemId != null,
          isSeeking: _isSeekDragging,
          isPageScrolling: _isPageScrolling,
          isViewportDragging: isViewportDragging,
        );
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
    final engine = _feedEngine;
    final intent = await engine.retryPlayback(item);
    if (!mounted) {
      return;
    }
    await _presentSheetIntent(context, item, intent);
  }

  Future<void> _presentSheetIntent(
    BuildContext context,
    PlayerFeedItem item,
    PlayerOverlaySheetIntent intent, {
    bool launchedByAutoSheet = false,
  }) async {
    if (!mounted) {
      return;
    }
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    try {
      await _unlockModalCoordinator.presentSheetIntent(
        context,
        item,
        intent,
        launchedByAutoSheet: launchedByAutoSheet,
      );
    } finally {
      if (mounted) {
        _isModalOpen = false;
        _activeCoinSheetItemId = null;
        _activeRechargeSheetItemId = null;
        _syncAutoImmersiveBlockers();
      }
    }
  }

  Future<void> _presentAutoUnlockSheetForItem(PlayerFeedItem item) async {
    final engine = _feedEngine;
    final result = await engine.prepareAutoUnlockSheet(
      item: item,
      isModalOpen: _isModalOpen,
      hasActiveCoinSheet: _activeCoinSheetItemId != null,
      hasActiveRechargeSheet: _activeRechargeSheetItemId != null,
    );
    if (!mounted) {
      return;
    }
    if (result.didAutoUnlock) {
      ref
          .read(appToastProvider)
          .success(context.l10n.playerUnlockedAutomatically);
      return;
    }
    await _presentSheetIntent(
      context,
      item,
      result.sheetIntent,
      launchedByAutoSheet: true,
    );
  }

  // TODO(engine): 选集编程跳转仍由 Page 驱动 PageController。
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
    _syncAutoImmersiveBlockers();
    
    // 重新获取完整的 content（包含推荐列表）
    final contentRepository = ref.read(playerContentRepositoryProvider);
    final contentFuture = contentRepository.getPlayerContent(dramaId: content.id);
    
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return FutureBuilder<PlayerContent>(
          future: contentFuture,
          builder: (context, snapshot) {
            final displayContent = snapshot.data ?? content;
            return PlayerDetailSheet(
              content: displayContent,
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
        );
      },
    ).whenComplete(() {
      _isModalOpen = false;
      if (mounted) {
        _syncAutoImmersiveBlockers();
      }
    });
  }

  Future<void> _showShareSheet() {
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const PlayerShareSheet(),
    ).whenComplete(() {
      _isModalOpen = false;
      if (mounted) {
        _syncAutoImmersiveBlockers();
      }
    });
  }

  Future<void> _showSpeedSheet() async {
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
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
    if (mounted) {
      _syncAutoImmersiveBlockers();
    }
  }

  Future<void> _showPendingUnlockActionSheet() async {
    if (_isModalOpen) {
      return;
    }
    final currentItem = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    if (currentItem == null) {
      return;
    }
    final engine = _feedEngine;
    final intent = await engine.prepareManualUnlock(currentItem);
    if (!mounted) {
      return;
    }
    if (_activeRechargeSheetItemId == currentItem.id ||
        _activeCoinSheetItemId == currentItem.id) {
      return;
    }
    if (intent == PlayerOverlaySheetIntent.coinUnlock) {
      _activeCoinSheetItemId = currentItem.id;
    } else if (intent == PlayerOverlaySheetIntent.rechargeUnlock ||
        intent == PlayerOverlaySheetIntent.membership) {
      _activeRechargeSheetItemId = currentItem.id;
    }
    await _presentSheetIntent(context, currentItem, intent);
  }

  void _openMembership() {
    context.push(RoutePaths.membership);
  }
}
