import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../../entitlement/domain/episode_access_decision.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../application/player_ui_controller.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_content.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_chrome.dart';
import '../widgets/player_detail_sheet.dart';
import '../widgets/player_recharge_unlock_sheet.dart';

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
  static const _autoUnlockSheetStableDelay = Duration(milliseconds: 120);
  static const _autoUnlockSheetMaxWait = Duration(milliseconds: 650);
  static const _autoUnlockSheetPostFrameDelay = Duration(milliseconds: 16);

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
  int _preloadRequestGeneration = 0;
  int _autoUnlockSheetGeneration = 0;
  String? _handledEndedItemId;
  final Set<String> _entitlementPlayableItemIds = <String>{};
  String? _activeCoinSheetItemId;
  String? _activeRechargeSheetItemId;
  String? _pendingAutoUnlockSheetItemId;
  Timer? _pendingAutoUnlockSheetStableTimer;
  Timer? _pendingAutoUnlockSheetMaxTimer;

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
    _cancelPendingAutoUnlockSheet();
    // 真正销毁页面实例时释放 session。底部 tab 切换不会 dispose For You 页面，它走
    // AppShell 的 pauseForVisibility；这里覆盖的是 app/test teardown 或 route 树销毁，
    // 不能只 pause，否则 Android VideoController 可能在树释放后仍收到 native callback。
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
      // feed currentItem 是播放链路入口。先问 entitlement，再决定是否播放或展示解锁
      // UI。PlayerPlaybackController 不知道金币/会员，仍只接收“已允许播放”的 item。
      unawaited(() async {
        await _handleEntitlementDecisionForItem(next, autoPresentSheet: false);
        if (!mounted) {
          return;
        }
        _scheduleAutoUnlockSheetForItem(next);
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
        canPop:
            widget.feedMode == PlayerFeedMode.forYou &&
            !widget.hideShellNavigation &&
            !uiState.showsPaywall,
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
            return;
          }

          if (widget.feedMode == PlayerFeedMode.singleDrama) {
            unawaited(_goBackFromPlayer());
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
                final isLockedCurrentItem =
                    isCurrentItem &&
                    item.episode.isLocked &&
                    !_isEntitlementPlayable(item) &&
                    !item.episode.isUnavailable;
                final lockedActionLabel =
                    uiState.paywall == PlayerPaywallState.memberUnlock
                    ? context.l10n.playerMemberUnlock
                    : context.l10n.playerUnlockNow;
                final canUsePlaybackSurface =
                    isCurrentItem &&
                    !item.episode.isUnavailable &&
                    _isEntitlementPlayable(item) &&
                    playbackState.shouldAttachVideoSurface &&
                    playbackState.currentItemId == item.id &&
                    playbackState.currentSource != null;
                final canRenderVideo = canUsePlaybackSurface;
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
                      videoController:
                          playbackState.canMountVideoSurface &&
                              canUsePlaybackSurface
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
                          _isEntitlementPlayable(item),
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
                      onRetry: () {
                        playbackController.recordPlaybackUserAction(
                          'retry tap',
                          trigger: 'retry',
                          fromItemId: playbackState.currentItemId,
                          toItemId: item.id,
                        );
                        unawaited(
                          _handleEntitlementDecisionForItem(
                            item,
                            autoPresentSheet: true,
                          ),
                        );
                      },
                      onDownloadTap:
                          widget.feedMode == PlayerFeedMode.singleDrama
                          ? () {}
                          : null,
                      isPlaying:
                          playbackState.isPlaying &&
                          isCurrentItem &&
                          !item.episode.isUnavailable &&
                          _isEntitlementPlayable(item),
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
                      showUnlockButton: isLockedCurrentItem,
                      unlockLabel: lockedActionLabel,
                      onUnlockTap: isLockedCurrentItem
                          ? () {
                              unawaited(_showPendingUnlockActionSheet());
                            }
                          : _openMembership,
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
                        onBackTap: () {
                          unawaited(_goBackFromPlayer());
                        },
                        onSpeedTap: _showSpeedSheet,
                      ),
                  ],
                );
              },
            ),
          ),
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
        _cancelPendingAutoUnlockSheet();
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
      final currentItem = ref
          .read(playerFeedControllerProvider(_sessionKey))
          .currentItem;
      if (currentItem != null) {
        _scheduleAutoUnlockSheetForItem(currentItem);
      }
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

  void _setSeekDragging(bool isDragging) {
    if (_isSeekDragging == isDragging || !mounted) {
      return;
    }
    // 拖动取消可能发生在 route teardown 的 widget tree lock 阶段。此时直接 setState 会
    // 让测试和真机退出链路变成非确定性，因此延后一帧做 UI 标记收口；播放控制器仍会
    // 立即收到 cancel/end，不影响真实 seek 状态。
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

  void _exitForYouFeed() {
    _shellChrome?.show();
    context.go(RoutePaths.home);
  }

  bool _isEntitlementPlayable(PlayerFeedItem item) {
    return !item.episode.isLocked ||
        _entitlementPlayableItemIds.contains(item.id);
  }

  PlayerFeedItem _playableCopy(PlayerFeedItem item) {
    if (!item.episode.isLocked) {
      return item;
    }
    return item.copyWith(episode: item.episode.copyWith(isLocked: false));
  }

  bool _isCurrentFeedItem(PlayerFeedItem item) {
    return ref
            .read(playerFeedControllerProvider(_sessionKey))
            .currentItem
            ?.id ==
        item.id;
  }

  bool _isLockedAutoSheetCandidate(PlayerFeedItem item) {
    return item.episode.isLocked &&
        !item.episode.isUnavailable &&
        !_isEntitlementPlayable(item);
  }

  void _cancelPendingAutoUnlockSheet() {
    _pendingAutoUnlockSheetStableTimer?.cancel();
    _pendingAutoUnlockSheetMaxTimer?.cancel();
    _pendingAutoUnlockSheetStableTimer = null;
    _pendingAutoUnlockSheetMaxTimer = null;
    _pendingAutoUnlockSheetItemId = null;
    _autoUnlockSheetGeneration += 1;
  }

  void _scheduleAutoUnlockSheetForItem(PlayerFeedItem item) {
    _pendingAutoUnlockSheetStableTimer?.cancel();
    _pendingAutoUnlockSheetMaxTimer?.cancel();
    _pendingAutoUnlockSheetStableTimer = null;
    _pendingAutoUnlockSheetMaxTimer = null;
    _pendingAutoUnlockSheetItemId = null;

    if (!mounted ||
        _isModalOpen ||
        _activeCoinSheetItemId != null ||
        _activeRechargeSheetItemId != null ||
        !_isLockedAutoSheetCandidate(item)) {
      return;
    }

    _pendingAutoUnlockSheetItemId = item.id;
    final generation = ++_autoUnlockSheetGeneration;

    _pendingAutoUnlockSheetStableTimer = Timer(_autoUnlockSheetStableDelay, () {
      _pendingAutoUnlockSheetStableTimer = null;
      _queueAutoUnlockSheetPresentation(
        item,
        generation: generation,
        allowWhileScrolling: false,
      );
    });
    _pendingAutoUnlockSheetMaxTimer = Timer(_autoUnlockSheetMaxWait, () {
      _pendingAutoUnlockSheetMaxTimer = null;
      _queueAutoUnlockSheetPresentation(
        item,
        generation: generation,
        allowWhileScrolling: true,
      );
    });
  }

  void _queueAutoUnlockSheetPresentation(
    PlayerFeedItem item, {
    required int generation,
    required bool allowWhileScrolling,
  }) {
    if (!mounted ||
        generation != _autoUnlockSheetGeneration ||
        _pendingAutoUnlockSheetItemId != item.id) {
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _autoUnlockSheetGeneration ||
          _pendingAutoUnlockSheetItemId != item.id) {
        return;
      }
      unawaited(() async {
        await Future<void>.delayed(_autoUnlockSheetPostFrameDelay);
        if (!mounted ||
            generation != _autoUnlockSheetGeneration ||
            _pendingAutoUnlockSheetItemId != item.id) {
          return;
        }
        await _showAutoUnlockSheetForItem(
          item,
          generation: generation,
          allowWhileScrolling: allowWhileScrolling,
        );
      }());
    });
  }

  Future<void> _showAutoUnlockSheetForItem(
    PlayerFeedItem item, {
    required int generation,
    required bool allowWhileScrolling,
  }) async {
    if (!mounted ||
        generation != _autoUnlockSheetGeneration ||
        !_isCurrentFeedItem(item) ||
        !_isLockedAutoSheetCandidate(item) ||
        (!allowWhileScrolling && _isPageScrolling) ||
        _isModalOpen ||
        _activeCoinSheetItemId != null ||
        _activeRechargeSheetItemId != null) {
      return;
    }

    _pendingAutoUnlockSheetStableTimer?.cancel();
    _pendingAutoUnlockSheetMaxTimer?.cancel();
    _pendingAutoUnlockSheetStableTimer = null;
    _pendingAutoUnlockSheetMaxTimer = null;
    _pendingAutoUnlockSheetItemId = null;

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

    if (!mounted ||
        generation != _autoUnlockSheetGeneration ||
        !_isCurrentFeedItem(item) ||
        (!_isLockedAutoSheetCandidate(item)) ||
        (!allowWhileScrolling && _isPageScrolling) ||
        _isModalOpen) {
      return;
    }

    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        await _handleAccessDecision(item, decision, autoPresentSheet: false);
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        await _showCoinUnlockSheetForItem(item);
      case EpisodeAccessDecisionType.showRechargeDialog:
        await _showRechargeUnlockSheetForItem(item);
      case EpisodeAccessDecisionType.goMembership:
      case EpisodeAccessDecisionType.waitUnlock:
        return;
    }
  }

  Future<void> _handleEntitlementDecisionForItem(
    PlayerFeedItem item, {
    required bool autoPresentSheet,
  }) async {
    if (!mounted) {
      return;
    }

    final uiController = ref.read(
      playerUiControllerProvider(_sessionKey).notifier,
    );
    uiController.selectEpisode(item.episode);

    final entitlementController = ref.read(
      entitlementControllerProvider.notifier,
    );
    final decision = entitlementController.evaluateAccess(
      dramaId: item.content.id,
      episodeId: item.episode.id,
      itemId: item.id,
      unlockType: item.episode.unlockType,
      price: item.episode.requiredCoins,
      isUnavailable: item.episode.isUnavailable,
    );

    await _handleAccessDecision(
      item,
      decision,
      autoPresentSheet: autoPresentSheet,
    );
  }

  Future<void> _handleAccessDecision(
    PlayerFeedItem item,
    EpisodeAccessDecision decision, {
    required bool autoPresentSheet,
  }) async {
    final uiController = ref.read(
      playerUiControllerProvider(_sessionKey).notifier,
    );
    final playbackController = ref.read(
      playerPlaybackControllerProvider(_sessionKey).notifier,
    );

    switch (decision.type) {
      case EpisodeAccessDecisionType.allowPlay:
        if (!_isCurrentFeedItem(item)) {
          return;
        }
        _entitlementPlayableItemIds.add(item.id);
        uiController.unlockPaywallAndPlay();
        _schedulePreloadAroundItem(item);
        await playbackController.playItem(_playableCopy(item));
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
        await playbackController.blockItem(
          item,
          status: PlayerPlaybackStatus.waitUnlock,
          reason: 'auto unlock requires current confirmation',
        );
        _schedulePreloadAroundItem(item);
        uiController.showUnlockPaywall();
        if (autoPresentSheet) {
          unawaited(_showCoinUnlockSheetForItem(item));
        }
      case EpisodeAccessDecisionType.goMembership:
        await playbackController.blockItem(
          item,
          status: PlayerPlaybackStatus.blocked,
          reason: decision.reason ?? 'membership required',
        );
        _schedulePreloadAroundItem(item);
        uiController.showMemberPaywall();
      case EpisodeAccessDecisionType.showCoinUnlockDialog:
        await playbackController.blockItem(
          item,
          status: PlayerPlaybackStatus.blocked,
          reason: decision.reason ?? 'coin unlock required',
        );
        _schedulePreloadAroundItem(item);
        uiController.showUnlockPaywall();
        if (autoPresentSheet) {
          unawaited(_showCoinUnlockSheetForItem(item));
        }
      case EpisodeAccessDecisionType.showRechargeDialog:
        await playbackController.blockItem(
          item,
          status: PlayerPlaybackStatus.blocked,
          reason: decision.reason ?? 'recharge required',
        );
        _schedulePreloadAroundItem(item);
        uiController.showUnlockPaywall();
        if (autoPresentSheet) {
          unawaited(_showRechargeUnlockSheetForItem(item));
        }
      case EpisodeAccessDecisionType.waitUnlock:
        await playbackController.blockItem(
          item,
          status: item.episode.isUnavailable
              ? PlayerPlaybackStatus.unavailable
              : PlayerPlaybackStatus.waitUnlock,
          reason: decision.reason ?? 'wait unlock',
        );
        _schedulePreloadAroundItem(item);
        if (item.episode.isUnavailable) {
          uiController.hidePaywall();
        } else {
          uiController.showUnlockPaywall();
        }
    }
  }

  void _schedulePreloadAroundItem(PlayerFeedItem item) {
    final requestGeneration = ++_preloadRequestGeneration;
    unawaited(() async {
      // Let the current item/index state settle for this frame, then start HLS
      // preload independently from media open. A slow or stuck current source
      // should not block the next candidates from warming.
      await Future<void>.delayed(Duration.zero);
      if (!mounted || requestGeneration != _preloadRequestGeneration) {
        return;
      }

      final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
      if (feedState.currentItem?.id != item.id || feedState.items.isEmpty) {
        return;
      }

      await ref
          .read(playerPlaybackControllerProvider(_sessionKey).notifier)
          .preloadAround(feedState.items, feedState.currentIndex);
    }());
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

  Future<void> _goBackFromPlayer() async {
    await _playbackController.detachSurfaceForDispose();
    // 给 Flutter 树一个 frame 先卸载 Video widget，再 pop route 触发 media session
    // dispose。这个顺序专门规避 Android native resize callback 晚于 Widget dispose 的
    // integration test teardown 问题，不改变播放器业务状态。
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

  Future<void> _showPendingUnlockActionSheet() async {
    _cancelPendingAutoUnlockSheet();
    if (_isModalOpen) {
      return;
    }
    final currentItem = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    if (currentItem == null ||
        !_isCurrentFeedItem(currentItem) ||
        !_isLockedAutoSheetCandidate(currentItem)) {
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
        await _handleAccessDecision(
          currentItem,
          decision,
          autoPresentSheet: false,
        );
      case EpisodeAccessDecisionType.autoUnlockAndPlay:
        await _showCoinUnlockSheetForItem(currentItem);
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

  Future<void> _showCoinUnlockSheetForItem(PlayerFeedItem item) async {
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

    if (!mounted || unlocked != true || !_isCurrentFeedItem(item)) {
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
    await _handleAccessDecision(item, decision, autoPresentSheet: false);
  }

  Future<void> _showRechargeUnlockSheetForItem(PlayerFeedItem item) async {
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
    if (!_isCurrentFeedItem(item)) {
      return;
    }
    await ref
        .read(playerPlaybackControllerProvider(_sessionKey).notifier)
        .blockItem(
          item,
          status: PlayerPlaybackStatus.waitUnlock,
          reason: selectedMembershipPackage == null
              ? 'recharge success awaiting coin confirmation'
              : 'membership purchase success awaiting user action',
        );
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .showUnlockPaywall();
    if (selectedCoinPackage != null) {
      unawaited(_showCoinUnlockSheetForItem(item));
    }
  }

  void _openMembership() {
    context.push(RoutePaths.membership);
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
