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
import '../../../pay/application/payment_loading_controller.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_feed_engine.dart';
import '../../application/player_feed_engine_access_flow.dart';
import '../../application/for_you_playback_progress_controller.dart';
import '../../application/player_like_controller.dart';
import '../../application/player_overlay_orchestrator.dart';
import '../../application/player_performance_policy_provider.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_unlock_modal_coordinator.dart';
import '../../application/player_rebuild_diagnostics.dart';
import '../../application/player_ui_controller.dart';
import '../../application/player_viewport_controller.dart';
import '../../data/dto/watch_progress_dto.dart';
import '../../data/playback_progress_repository_provider.dart';
import '../../data/player_content_repository_provider.dart';
import '../../data/player_remote_data_source_provider.dart';
import '../../../membership/presentation/membership_route_result.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/for_you_player_handoff.dart';
import '../../domain/player_performance_policy.dart';
import '../../domain/player_content.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_playback_progress.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_detail_sheet.dart';
import '../widgets/player_feed_page_shell.dart';
import '../widgets/player_playback_layer.dart';
import '../widgets/player_subtitle_overlay.dart';
import '../widgets/player_subtitle_sheet.dart';

/// 鎾斁鍣?UI 瀹夸富锛氱旱鍚?[PageView] + 椤跺眰鍗曚緥 Video surface + sheet銆?
///
/// 鑱岃矗杈圭晫锛?
/// - 鏈枃浠讹細甯冨眬銆佹墜鍔胯浆鍙戙€佸眬閮?sheet锛堣鎯?鍒嗕韩/鍊嶉€燂級銆佽В閿佸脊绐楀鎵?AppModal銆?
/// - [PlayerFeedEngine]锛歷iewport settled銆佹潈鐩?鎾斁/棰勫姞杞?寮圭獥璋冨害锛堜笉鍦?drag 璺緞璋冪敤锛夈€?
/// - [PlayerPlaybackController]锛歮edia_kit 鐪熷疄鐘舵€侊紙position/play/source锛夛紝涓嶅惈 sheet 涓氬姟銆?
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({
    required this.dramaId,
    required this.episodeId,
    this.feedMode = PlayerFeedMode.singleDrama,
    this.hideShellNavigation = false,
    this.initialPlaybackTrigger,
    this.initialUserActionAt,
    this.forYouHandoff,
    super.key,
  });

  const PlayerPage.forYou({super.key})
    : dramaId = null,
      episodeId = null,
      feedMode = PlayerFeedMode.forYou,
      hideShellNavigation = false,
      initialPlaybackTrigger = 'for_you_tab',
      initialUserActionAt = null,
      forYouHandoff = null;

  final String? dramaId;
  final String? episodeId;
  final PlayerFeedMode feedMode;
  final bool hideShellNavigation;
  final String? initialPlaybackTrigger;
  final DateTime? initialUserActionAt;
  final ForYouPlayerHandoff? forYouHandoff;

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
  WatchProgressDto? _startupRemoteWatchProgress;
  String? _initialResumeEpisodeId;
  bool _isSeekDragging = false;
  bool _isModalOpen = false;
  bool _isAutoAdvancing = false;
  bool _isOpeningRecommendation = false;
  bool _isOpeningSearch = false;
  bool _isOpeningForYouPlayer = false;
  bool _isPressingPlaybackSurface = false;
  bool _isPageScrolling = false;
  bool _didRecordFirstBuild = false;
  bool _allowRemoteResumeEpisodeSwitch = true;
  String? _activeCoinSheetItemId;
  String? _activeRechargeSheetItemId;
  AppLifecycleState _previousLifecycleState = AppLifecycleState.resumed;
  bool _wasPlayingBeforeInactive = false;
  bool _resumePlaybackOnLifecycleResume = false;
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
      final remoteResumeFuture = _loadRemoteResumeProgress();

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

      // 姣忔杩涘叆鎾斁椤垫椂锛屽埛鏂扮偣璧炵姸鎬?
      if (widget.dramaId != null) {
        final likeController = ref.read(
          playerLikeControllerProvider(widget.dramaId!).notifier,
        );
        unawaited(likeController.refreshLikeStatus());
      }

      await _loadFeedForTiming(remoteResumeFuture: remoteResumeFuture);
    });
  }

  @override
  void dispose() {
    // 涓婃姤瑙傜湅閫€鍑轰簨浠?
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
    final previous = _previousLifecycleState;
    _previousLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      // 浠?inactive 鎭㈠锛堝涓嬫媺鐘舵€佹爮鍚庢敹鍥烇級锛岃嫢涔嬪墠姝ｅ湪鎾斁鍒欒嚜鍔ㄦ仮澶?
      final shouldResumePlayback =
          _resumePlaybackOnLifecycleResume ||
          (previous == AppLifecycleState.inactive && _wasPlayingBeforeInactive);
      _resumePlaybackOnLifecycleResume = false;
      _wasPlayingBeforeInactive = false;
      if (shouldResumePlayback) {
        unawaited(_resumePlaybackAfterLifecyclePause());
      }
      return;
    }
    // 璁板綍杩涘叆 inactive 鍓嶆槸鍚︽鍦ㄦ挱鏀撅紝鐢ㄤ簬鎭㈠鏃跺垽鏂槸鍚﹂渶瑕佽嚜鍔ㄦ挱鏀?
    if (state == AppLifecycleState.inactive) {
      _wasPlayingBeforeInactive = ref
          .read(playerPlaybackControllerProvider(_sessionKey))
          .isPlaying;
      _resumePlaybackOnLifecycleResume =
          _resumePlaybackOnLifecycleResume || _wasPlayingBeforeInactive;
      unawaited(_playbackController.pause());
      return;
    }
    // paused/detached锛氬垏鎹㈠埌鍚庡彴锛屽畬鍏ㄦ殏鍋滃苟绉婚櫎瑙嗛鐢婚潰浠ラ噴鏀捐祫婧?
    _resumePlaybackOnLifecycleResume =
        _resumePlaybackOnLifecycleResume ||
        ref.read(playerPlaybackControllerProvider(_sessionKey)).isPlaying;
    unawaited(_playbackController.pauseForVisibility());
  }

  @override
  void didHaveMemoryPressure() {
    unawaited(_playbackController.releaseSessionWindow());
  }

  Future<void> _resumePlaybackAfterLifecyclePause() async {
    await _playbackController.resumeAfterVisibilityPause();
    if (!mounted) {
      return;
    }
    _restoreChromeAfterReturningToPlayer();
  }

  void _restoreChromeAfterReturningToPlayer() {
    if (widget.feedMode != PlayerFeedMode.singleDrama) {
      return;
    }
    final uiController = ref.read(
      playerUiControllerProvider(_sessionKey).notifier,
    );
    uiController.showDefaultChrome();
    _syncAutoImmersiveBlockers();
    uiController.notifyUserInteraction();
  }

  PlayerFeedConfig get _feedConfig {
    return switch (widget.feedMode) {
      PlayerFeedMode.singleDrama => PlayerFeedConfig.singleDrama(
        dramaId: widget.dramaId!,
        episodeId: _initialResumeEpisodeId ?? widget.episodeId!,
      ),
      PlayerFeedMode.forYou => const PlayerFeedConfig.forYou(),
    };
  }

  Future<void> _loadRemoteResumeProgress() async {
    if (widget.feedMode != PlayerFeedMode.singleDrama ||
        widget.dramaId == null ||
        widget.forYouHandoff != null ||
        !ref.read(useRemotePlayerApiProvider)) {
      return;
    }
    final dramaId = int.tryParse(widget.dramaId!);
    if (dramaId == null) {
      return;
    }
    try {
      final watchProgress = await ref
          .read(playerRemoteDataSourceProvider)
          .fetchWatchProgress(dramaId: dramaId);
      if (watchProgress == null || !mounted) {
        return;
      }
      final remotePosition = Duration(seconds: watchProgress.watchSecond);
      final remoteDuration = Duration(seconds: watchProgress.durationSecond);
      final remoteCanResume =
          remotePosition > Duration.zero &&
          remoteDuration > Duration.zero &&
          remotePosition < remoteDuration - const Duration(seconds: 2);
      _startupRemoteWatchProgress = watchProgress;
      if (remoteCanResume) {
        _initialResumeEpisodeId = watchProgress.episodeId.toString();
      }
    } catch (error) {
      developer.log('Failed to fetch watch progress: $error', error: error);
    }
  }

  Future<void> _loadFeedForTiming({Future<void>? remoteResumeFuture}) async {
    final feedProvider = playerFeedControllerProvider(_sessionKey);
    final feedController = ref.read(feedProvider.notifier);
    if (remoteResumeFuture != null) {
      await remoteResumeFuture.timeout(
        const Duration(milliseconds: 1800),
        onTimeout: () {},
      );
      if (!mounted) {
        return;
      }
    }
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
    var feedState = ref.read(feedProvider);
    if (feedState.currentItem != null) {
      if (widget.forYouHandoff != null) {
        _applyInitialForYouHandoffProgress(feedState);
      } else {
        await _applyStartupRemoteResumeProgress(feedState);
      }
      if (!mounted) {
        return;
      }
      feedState = ref.read(feedProvider);
      if (feedState.currentItem == null) {
        return;
      }
      // 璁剧疆寰呮仮澶嶇殑鎾斁杩涘害锛堜粠鎾斁鍘嗗彶杩涘叆鏃讹級
      final playbackState = ref.read(
        playerPlaybackControllerProvider(_sessionKey),
      );
      if (_resumeProgress != null &&
          playbackState.currentItemId == null &&
          playbackState.currentSource == null) {
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

  void _applyInitialForYouHandoffProgress(PlayerFeedState feedState) {
    final handoff = widget.forYouHandoff;
    if (handoff == null || feedState.currentItem == null) {
      return;
    }
    final targetIndex = feedState.items.indexWhere(
      (item) => item.episode.id == handoff.episodeId,
    );
    if (targetIndex != -1 && targetIndex != feedState.currentIndex) {
      ref
          .read(playerFeedControllerProvider(_sessionKey).notifier)
          .setCurrentIndex(targetIndex);
      feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    }
    final targetItem = feedState.currentItem;
    if (targetItem == null) {
      return;
    }
    final duration = handoff.duration > Duration.zero
        ? handoff.duration
        : targetItem.episode.duration ?? Duration.zero;
    final progress = PlaybackProgress(
      itemId: targetItem.id,
      position: handoff.position,
      duration: duration,
      updatedAt: DateTime.now(),
    );
    _resumeProgress = progress;
    if (progress.canResume) {
      _playbackController.setPendingResumeProgress(progress);
    }
  }

  Future<void> _applyStartupRemoteResumeProgress(
    PlayerFeedState feedState,
  ) async {
    final watchProgress = _startupRemoteWatchProgress;
    if (watchProgress == null || feedState.items.isEmpty) {
      return;
    }
    _startupRemoteWatchProgress = null;

    final remoteItemIndex = _indexForRemoteWatchProgress(
      feedState.items,
      watchProgress,
    );
    if (remoteItemIndex == -1) {
      developer.log(
        'Skip remote watch progress: target episode missing '
        'episodeId=${watchProgress.episodeId}, '
        'episodeNo=${watchProgress.episodeNo}',
      );
      return;
    }

    var targetIndex = remoteItemIndex;
    final remotePosition = Duration(seconds: watchProgress.watchSecond);
    final remoteDuration = Duration(seconds: watchProgress.durationSecond);
    final canResume =
        remotePosition > Duration.zero &&
        remoteDuration > Duration.zero &&
        remotePosition < remoteDuration - const Duration(seconds: 2);
    if (!canResume && remoteItemIndex + 1 < feedState.items.length) {
      targetIndex = remoteItemIndex + 1;
    }

    final targetItem = feedState.items[targetIndex];
    final progress = PlaybackProgress(
      itemId: targetItem.id,
      position: canResume ? remotePosition : Duration.zero,
      duration: canResume ? remoteDuration : Duration.zero,
      updatedAt: DateTime.now(),
    );
    _resumeProgress = progress;

    if (progress.canResume) {
      _playbackController.setPendingResumeProgress(progress);
      unawaited(
        ref.read(playbackProgressRepositoryProvider).saveProgress(progress),
      );
    }

    final playbackState = ref.read(
      playerPlaybackControllerProvider(_sessionKey),
    );
    final playbackHasStarted =
        playbackState.currentItemId != null ||
        playbackState.currentSource != null ||
        playbackState.position > Duration.zero ||
        playbackState.hasFirstFrame ||
        playbackState.hasEnded;
    final isStaleForCurrentPlayback =
        progress.canResume &&
        playbackState.currentItemId == progress.itemId &&
        (playbackState.hasEnded ||
            playbackState.position >
                progress.position + const Duration(seconds: 1));
    if (isStaleForCurrentPlayback) {
      developer.log(
        'Skip stale remote watch progress: '
        'itemId=${progress.itemId}, '
        'remote=${progress.position.inSeconds}s, '
        'current=${playbackState.position.inSeconds}s, '
        'hasEnded=${playbackState.hasEnded}',
      );
      return;
    }
    if (progress.canResume && feedState.currentItem?.id == progress.itemId) {
      await _playbackController.restoreCurrentProgress(progress);
      return;
    }
    if (!_allowRemoteResumeEpisodeSwitch ||
        playbackHasStarted ||
        targetIndex == feedState.currentIndex ||
        _isPageScrolling) {
      return;
    }
    ref
        .read(playerFeedControllerProvider(_sessionKey).notifier)
        .setCurrentIndex(targetIndex);
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        targetIndex,
        duration: _pageTransitionDuration,
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted) {
      _settleViewportAtIndex(targetIndex);
    }
  }

  int _indexForRemoteWatchProgress(
    List<PlayerFeedItem> items,
    WatchProgressDto watchProgress,
  ) {
    return items.indexWhere((item) {
      return item.episode.id == watchProgress.episodeId.toString() ||
          item.episode.number == watchProgress.episodeNo;
    });
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
    final isPaymentLoading = ref.watch(
      paymentLoadingControllerProvider.select((state) => state.isVisible),
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
        var settledItem = latestFeedState.items[next.index];
        if (settledItem.id != next.itemId) {
          return;
        }
        if (widget.feedMode == PlayerFeedMode.forYou) {
          final cached = ref
              .read(forYouPlaybackProgressControllerProvider.notifier)
              .snapshotFor(settledItem.content.id);
          if (cached != null) {
            if (settledItem.episode.id != cached.episode.id) {
              settledItem =
                  ref
                      .read(feedProvider.notifier)
                      .updateItemEpisode(
                        itemId: settledItem.id,
                        episode: cached.episode,
                      ) ??
                  settledItem;
            }
            final progress = PlaybackProgress(
              itemId: settledItem.id,
              position: cached.position,
              duration: cached.duration,
              updatedAt: cached.updatedAt,
            );
            if (progress.canResume) {
              playbackController.setPendingResumeProgress(progress);
            }
          }
          if (ref.read(useRemotePlayerApiProvider)) {
            final dramaId = int.tryParse(settledItem.content.id);
            if (dramaId != null && dramaId > 0) {
              ref.read(playerDramaDetailCacheProvider).prefetch(dramaId);
            }
          }
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

    // Defer锛歠eed 缂栫▼鍒囬〉浠嶇洿鎺ラ┍鍔?PageController锛堥潪鐢ㄦ埛 drag锛夛紝瑙?_closeSheetAndSelectEpisode銆?
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
      playerPlaybackControllerProvider(sessionKey).select(
        (state) => (
          state.currentItemId,
          state.currentSource,
          state.position,
          state.duration,
          state.hasEnded,
        ),
      ),
      (previous, next) {
        if (next.$1 == null ||
            next.$2 == null ||
            (next.$3 <= Duration.zero && !next.$5)) {
          return;
        }
        final latestFeed = ref.read(feedProvider);
        PlayerFeedItem? playingItem;
        for (final candidate in latestFeed.items) {
          if (candidate.id == next.$1) {
            playingItem = candidate;
            break;
          }
        }
        if (playingItem == null) {
          return;
        }
        final handoff = widget.forYouHandoff;
        if (widget.feedMode != PlayerFeedMode.forYou && handoff == null) {
          return;
        }
        ref
            .read(forYouPlaybackProgressControllerProvider.notifier)
            .save(
              ForYouPlaybackSnapshot(
                originItemId: handoff?.originItemId ?? playingItem.id,
                dramaId: playingItem.content.id,
                episode: playingItem.episode,
                position: next.$3,
                duration: next.$4 > Duration.zero
                    ? next.$4
                    : playingItem.episode.duration ?? Duration.zero,
                updatedAt: DateTime.now(),
              ),
            );
      },
    );

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
        // 涓婃姤瑙傜湅瀹屾垚浜嬩欢
        unawaited(
          playbackController.reportWatchProgress(eventType: 6),
        ); // 6: complete
        feedEngine.markEndedHandled(next.$1!);
        if (widget.feedMode == PlayerFeedMode.forYou) {
          final completedItem = ref.read(feedProvider).currentItem;
          if (completedItem != null) {
            unawaited(
              _openForYouItemInPlayer(completedItem, rewindFromEnd: true),
            );
          }
        } else if (feedSnapshot.$5) {
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
            !isPaymentLoading &&
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
          currentIndex: feedSnapshot.$4,
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
    required int currentIndex,
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
        message: context.l10n.noData,
      );
    }
    _schedulePageControllerAlignment(
      targetIndex: currentIndex,
      itemCount: items.length,
      settledIndex: viewportState.settledIndex,
    );

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
                  : const PageScrollPhysics(parent: ClampingScrollPhysics()),
              scrollDirection: Axis.vertical,
              itemCount: items.length,
              onPageChanged: (index) {
                feedEngine.onPageChanged(index);
                if (widget.feedMode == PlayerFeedMode.forYou &&
                    index == items.length - 1) {
                  unawaited(feedController.loadMore());
                }
              },
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
                    unawaited(
                      _openForYouItemInPlayer(item, rewindFromEnd: false),
                    );
                  },
                  onSearchTap: widget.feedMode == PlayerFeedMode.forYou
                      ? () => unawaited(_openSearch())
                      : null,
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
                  onMetaTap: () {
                    _showDetailSheet(
                      item.content,
                      initialTab: PlayerDetailTab.synopsis,
                    );
                  },
                  onUnlockTap: () {
                    unawaited(_showPendingUnlockActionSheet());
                  },
                  onOpenMembership: () {
                    unawaited(_openMembership());
                  },
                  showChromeOverlays: widget.feedMode == PlayerFeedMode.forYou
                      ? true
                      : showsChromeOverlays,
                  chromeOverlayFadeDuration: chromeOverlayFadeDuration,
                  useSingleDramaChromeTap:
                      widget.feedMode == PlayerFeedMode.singleDrama,
                  onExitImmersiveChrome:
                      widget.feedMode == PlayerFeedMode.singleDrama
                      ? () {
                          uiController.onImmersiveVideoTap();
                          unawaited(playbackController.togglePlay());
                        }
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
                onSubtitleTap: _showSubtitleSheet,
              ),
            ),
          ),
        // 瀛楀箷鍙犲姞灞?
        PlayerSubtitleOverlay(sessionKey: _sessionKey),
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

  void _schedulePageControllerAlignment({
    required int targetIndex,
    required int itemCount,
    required int settledIndex,
  }) {
    if (targetIndex < 0 ||
        targetIndex >= itemCount ||
        settledIndex != targetIndex ||
        _isPageScrolling ||
        _isAutoAdvancing) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_pageController.hasClients ||
          _isPageScrolling ||
          _isAutoAdvancing) {
        return;
      }
      final latestFeedState = ref.read(
        playerFeedControllerProvider(_sessionKey),
      );
      final latestViewport = ref.read(
        playerViewportControllerProvider(_sessionKey),
      );
      if (latestFeedState.currentIndex != targetIndex ||
          latestViewport.settledIndex != targetIndex ||
          latestViewport.scrollPhase != PlayerViewportScrollPhase.idle) {
        return;
      }
      final currentPage = _pageController.page?.round();
      if (currentPage == targetIndex) {
        return;
      }
      _pageController.jumpToPage(targetIndex);
      _settleViewportAtIndex(targetIndex);
      _syncActiveVideoPagePosition();
    });
  }

  bool _handlePageScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification) {
      if (notification is ScrollStartNotification) {
        _allowRemoteResumeEpisodeSwitch = false;
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

  Future<void> _openForYouItemInPlayer(
    PlayerFeedItem item, {
    required bool rewindFromEnd,
  }) async {
    if (_isOpeningForYouPlayer ||
        widget.feedMode != PlayerFeedMode.forYou ||
        !mounted) {
      return;
    }
    final playbackState = ref.read(
      playerPlaybackControllerProvider(_sessionKey),
    );
    final isCurrentPlayableItem =
        playbackState.currentItemId == item.id &&
        playbackState.currentSource != null &&
        (playbackState.status == PlayerPlaybackStatus.playing ||
            playbackState.status == PlayerPlaybackStatus.paused);
    if (!isCurrentPlayableItem) {
      return;
    }

    _isOpeningForYouPlayer = true;
    try {
      final effectiveDuration = playbackState.duration > Duration.zero
          ? playbackState.duration
          : item.episode.duration ?? Duration.zero;
      final initialPosition = rewindFromEnd
          ? Duration(
              milliseconds: (effectiveDuration - const Duration(seconds: 5))
                  .inMilliseconds
                  .clamp(0, effectiveDuration.inMilliseconds),
            )
          : playbackState.position;
      final handoff = ForYouPlayerHandoff(
        id: '${item.id}:${DateTime.now().microsecondsSinceEpoch}',
        originItemId: item.id,
        dramaId: item.content.id,
        episodeId: item.episode.id,
        position: initialPosition,
        duration: effectiveDuration,
      );
      ref
          .read(forYouPlaybackProgressControllerProvider.notifier)
          .save(
            ForYouPlaybackSnapshot(
              originItemId: item.id,
              dramaId: item.content.id,
              episode: item.episode,
              position: initialPosition,
              duration: effectiveDuration,
              updatedAt: DateTime.now(),
            ),
          );

      await _playbackController.pauseForRouteHandoff();
      if (!mounted) {
        return;
      }
      final location = RoutePaths.playerLocation(
        dramaId: item.content.id,
        episodeId: item.episode.id,
        trigger: rewindFromEnd ? 'for_you_complete' : 'for_you_watch_now',
        userActionAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final returned = await context.push<ForYouPlaybackSnapshot>(
        location,
        extra: handoff,
      );
      if (!mounted) {
        return;
      }
      if (returned != null) {
        ref
            .read(forYouPlaybackProgressControllerProvider.notifier)
            .save(returned);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) {
          return;
        }
        await _synchronizeReturnedForYouProgress(returned);
      }
    } finally {
      _isOpeningForYouPlayer = false;
    }
  }

  Duration _forYouResumePosition(Duration position, Duration duration) {
    if (duration > Duration.zero &&
        position >= duration - const Duration(seconds: 1)) {
      final rewind = duration - const Duration(seconds: 5);
      return rewind > Duration.zero ? rewind : Duration.zero;
    }
    return position;
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
    final handoffResult = _currentForYouHandoffSnapshot();
    if (handoffResult != null) {
      await _playbackController.detachSurfaceForRoutePop();
    } else {
      // 非 For You 入口保留原来的强释放顺序，避免改变首页进入普通播放页的行为。
      await _playbackController.persistCurrentProgress();
      await _playbackController.detachSurfaceForDispose();
    }
    await WidgetsBinding.instance.endOfFrame;
    _playbackController.markSurfaceDetached();
    if (handoffResult == null &&
        PlayerPlaybackController.shouldDelayVideoSurfaceTeardown) {
      await Future<void>.delayed(
        PlayerPlaybackController.videoSurfaceTeardownDelay,
      );
    }
    if (!mounted) {
      return;
    }
    if (context.canPop()) {
      context.pop(handoffResult);
    } else {
      context.go(RoutePaths.home);
    }
  }

  Future<void> _synchronizeReturnedForYouProgress(
    ForYouPlaybackSnapshot snapshot,
  ) async {
    ref.read(forYouPlaybackProgressControllerProvider.notifier).save(snapshot);
    final updatedItem = ref
        .read(
          playerFeedControllerProvider(
            PlayerPlaybackSessionKeys.forYouTab,
          ).notifier,
        )
        .updateItemEpisode(
          itemId: snapshot.originItemId,
          episode: snapshot.episode,
        );
    if (updatedItem == null) {
      return;
    }
    await ref
        .read(
          playerPlaybackControllerProvider(
            PlayerPlaybackSessionKeys.forYouTab,
          ).notifier,
        )
        .synchronizeExternalProgress(
          item: updatedItem,
          position: _forYouResumePosition(snapshot.position, snapshot.duration),
          duration: snapshot.duration,
        );
  }

  ForYouPlaybackSnapshot? _currentForYouHandoffSnapshot() {
    final handoff = widget.forYouHandoff;
    if (handoff == null) {
      return null;
    }
    final playback = ref.read(playerPlaybackControllerProvider(_sessionKey));
    final feed = ref.read(playerFeedControllerProvider(_sessionKey));
    PlayerFeedItem? currentItem;
    for (final item in feed.items) {
      if (item.id == playback.currentItemId) {
        currentItem = item;
        break;
      }
    }
    if (currentItem == null || playback.currentSource == null) {
      return ref
          .read(forYouPlaybackProgressControllerProvider.notifier)
          .snapshotFor(handoff.dramaId);
    }
    final snapshot = ForYouPlaybackSnapshot(
      originItemId: handoff.originItemId,
      dramaId: currentItem.content.id,
      episode: currentItem.episode,
      position: playback.position,
      duration: playback.duration > Duration.zero
          ? playback.duration
          : currentItem.episode.duration ?? Duration.zero,
      updatedAt: DateTime.now(),
    );
    ref.read(forYouPlaybackProgressControllerProvider.notifier).save(snapshot);
    return snapshot;
  }

  Future<void> _openRecommendationFromDetailSheet(
    BuildContext sheetContext,
    PlayerRecommendation recommendation,
  ) async {
    if (_isOpeningRecommendation) {
      return;
    }
    _isOpeningRecommendation = true;
    try {
      if (Navigator.of(sheetContext).canPop()) {
        Navigator.of(sheetContext).pop();
      }

      final shouldResumeWhenRecommendationReturns = ref
          .read(playerPlaybackControllerProvider(_sessionKey))
          .isPlaying;
      await _playbackController.pauseForVisibility();
      if (!mounted) {
        return;
      }

      final location = RoutePaths.playerLocation(
        dramaId: recommendation.id,
        episodeId: '1',
        trigger: 'recommendation',
        userActionAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      await context.push<void>(location);
      if (!mounted) {
        return;
      }
      if (shouldResumeWhenRecommendationReturns &&
          _previousLifecycleState == AppLifecycleState.resumed) {
        await _playbackController.resumeAfterVisibilityPause();
        if (!mounted) {
          return;
        }
      }
      _restoreChromeAfterReturningToPlayer();
    } finally {
      _isOpeningRecommendation = false;
    }
  }

  Future<void> _openSearch() async {
    if (_isOpeningSearch ||
        widget.feedMode != PlayerFeedMode.forYou ||
        !mounted) {
      return;
    }
    _isOpeningSearch = true;
    try {
      await _playbackController.pauseForVisibility();
      if (!mounted) {
        return;
      }

      await context.push<void>(RoutePaths.search);
      if (!mounted) {
        return;
      }
      if (_previousLifecycleState == AppLifecycleState.resumed) {
        await _playbackController.resumeAfterVisibilityPause();
      }
    } finally {
      _isOpeningSearch = false;
    }
  }

  Future<void> _retryPlaybackForItem(PlayerFeedItem item) async {
    // 閲嶈瘯鍓嶉噸鏂拌幏鍙栧巻鍙叉挱鏀捐繘搴︼紝鍥犱负 _pendingResumeProgress
    // 鍦ㄧ涓€娆?playItem 鏃跺凡缁忚娑堣垂骞舵竻绌猴紙绗?737 琛岋級
    if (widget.feedMode == PlayerFeedMode.singleDrama &&
        widget.dramaId != null) {
      try {
        final dramaId = int.tryParse(widget.dramaId!);
        if (dramaId != null) {
          final dataSource = ref.read(playerRemoteDataSourceProvider);
          final watchProgress = await dataSource.fetchWatchProgress(
            dramaId: dramaId,
          );
          if (watchProgress != null && mounted) {
            // 閲嶆柊鏋勫缓涓?PlayerFeedItem 涓€鑷寸殑 id 鏍煎紡锛?single:{content.id}:{episode.id}'
            final contentId = widget.dramaId!;
            final episodeId = watchProgress.episodeId.toString();
            _resumeProgress = PlaybackProgress(
              itemId: 'single:$contentId:$episodeId',
              position: Duration(seconds: watchProgress.watchSecond),
              duration: Duration(seconds: watchProgress.durationSecond),
              updatedAt: DateTime.now(),
            );
            _playbackController.setPendingResumeProgress(_resumeProgress);
            developer.log(
              '_retryPlaybackForItem: 閲嶆柊璁剧疆鎭㈠杩涘害 - '
              'position=${_resumeProgress!.position.inSeconds}s',
            );
          }
        }
      } catch (e) {
        developer.log('_retryPlaybackForItem: 鑾峰彇鍘嗗彶杩涘害澶辫触 - $e');
      }
    }

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
        _restoreUnlockPaywallAfterModalIfNeeded(item);
        _syncAutoImmersiveBlockers();
      }
    }
  }

  void _restoreUnlockPaywallAfterModalIfNeeded(PlayerFeedItem item) {
    final currentItem = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    if (currentItem == null ||
        currentItem.id != item.id ||
        !currentItem.episode.isLocked ||
        currentItem.episode.isUnavailable ||
        _feedEngine.accessPresentationFor(currentItem) ==
            PlayerAccessPresentationState.playable) {
      return;
    }
    ref
        .read(playerUiControllerProvider(_sessionKey).notifier)
        .showUnlockPaywall();
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
      return;
    }
    await _presentSheetIntent(
      context,
      item,
      result.sheetIntent,
      launchedByAutoSheet: true,
    );
  }

  // TODO(engine): 閫夐泦缂栫▼璺宠浆浠嶇敱 Page 椹卞姩 PageController銆?
  void _closeSheetAndSelectEpisode(
    BuildContext sheetContext,
    PlayerEpisode episode,
  ) {
    Navigator.of(sheetContext).pop();
    if (!mounted) {
      return;
    }
    _allowRemoteResumeEpisodeSwitch = false;
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

    // 閲嶆柊鑾峰彇瀹屾暣鐨?content锛堝寘鍚帹鑽愬垪琛級
    final contentRepository = ref.read(playerContentRepositoryProvider);
    final contentFuture = contentRepository.getPlayerContent(
      dramaId: content.id,
    );

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
              onRecommendationSelected: (recommendation) {
                unawaited(
                  _openRecommendationFromDetailSheet(
                    sheetContext,
                    recommendation,
                  ),
                );
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

  Future<void> _showSubtitleSheet() async {
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return PlayerSubtitleSheet(sessionKey: _sessionKey);
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

  Future<void> _openMembership() async {
    final item = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    final result = await context.push<MembershipRouteResult>(
      RoutePaths.membership,
    );
    if (!mounted || result != MembershipRouteResult.purchaseCompleted) {
      return;
    }
    await _continueCurrentEpisodeAfterMembershipSuccess(item);
  }

  Future<void> _continueCurrentEpisodeAfterMembershipSuccess(
    PlayerFeedItem? item,
  ) async {
    final currentItem =
        item ?? ref.read(playerFeedControllerProvider(_sessionKey)).currentItem;
    if (currentItem == null) {
      return;
    }
    final flowResult = await _feedEngine.continueAfterRechargeSuccess(
      item: currentItem,
      grantedCoinPackage: false,
      grantedMembershipPackage: true,
    );
    if (!mounted) {
      return;
    }
    if (flowResult.didActivateMembership) {
      ref
          .read(appToastProvider)
          .success(context.l10n.playerMembershipActivated);
      return;
    }
    await _presentSheetIntent(context, currentItem, flowResult.sheetIntent);
  }
}
