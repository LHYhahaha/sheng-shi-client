import 'dart:developer' as developer;
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/router/player_route_observer.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/locale/app_locale_controller.dart';
import '../../../../core/runtime/api_lang_provider.dart';
import '../../../../core/toast/app_center_toast.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/url/external_url_launcher.dart';
import '../../../pay/application/payment_loading_controller.dart';
import '../../data/player_exit_recommendation_history_repository_provider.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_session.dart';
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
import '../../application/player_session_registry.dart';
import '../../application/player_ui_controller.dart';
import '../../application/player_viewport_controller.dart';
import '../../data/dto/watch_progress_dto.dart';
import '../../data/playback_progress_repository_provider.dart';
import '../../data/player_content_repository_provider.dart';
import '../../data/player_remote_data_source_provider.dart';
import '../../../popup/data/popup_repository_provider.dart';
import '../../../popup/domain/popup.dart';
import '../../../membership/presentation/membership_route_result.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/for_you_player_handoff.dart';
import '../../domain/player_performance_policy.dart';
import '../../domain/player_content.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_playback_progress.dart';
import '../../domain/player_subtitle.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_detail_sheet.dart';
import '../widgets/player_exit_recommendation_dialog.dart';
import '../widgets/player_feed_page_shell.dart';
import '../widgets/player_playback_layer.dart';

sealed class _ExitRecommendationDialogResult {
  const _ExitRecommendationDialogResult();
}

final class _ExitRecommendationExitResult
    extends _ExitRecommendationDialogResult {
  const _ExitRecommendationExitResult();
}

final class _ExitRecommendationPlayResult
    extends _ExitRecommendationDialogResult {
  const _ExitRecommendationPlayResult(this.recommendation);

  final PopupExitRecommendation recommendation;
}

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
    this.initialExitRecommendationsForTesting,
    this.initialExitRecommendationPopupIdForTesting,
    super.key,
  });

  const PlayerPage.forYou({super.key})
    : dramaId = null,
      episodeId = null,
      feedMode = PlayerFeedMode.forYou,
      hideShellNavigation = false,
      initialPlaybackTrigger = 'for_you_tab',
      initialUserActionAt = null,
      forYouHandoff = null,
      initialExitRecommendationsForTesting = null,
      initialExitRecommendationPopupIdForTesting = null;

  final String? dramaId;
  final String? episodeId;
  final PlayerFeedMode feedMode;
  final bool hideShellNavigation;
  final String? initialPlaybackTrigger;
  final DateTime? initialUserActionAt;
  final ForYouPlayerHandoff? forYouHandoff;
  final List<PopupExitRecommendation>? initialExitRecommendationsForTesting;
  final int? initialExitRecommendationPopupIdForTesting;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver, RouteAware {
  static const _autoAdvanceDuration = Duration(milliseconds: 300);
  static const _pageTransitionDuration = Duration(milliseconds: 260);
  static const _dimmedOverlayOpacity = 0.64;
  static const _remoteResumeInitialWait = Duration(milliseconds: 450);
  static const _lockedNextEpisodeRewind = Duration(seconds: 8);
  static const _forYouNearEndRestartThreshold = Duration(seconds: 8);

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
  bool _isReloadingForYouAfterLanguageChange = false;
  bool _hasPendingForYouLanguageReload = false;
  bool _isRefreshingForYouFeed = false;
  bool _isLeavingRoute = false;
  bool _isPressingPlaybackSurface = false;
  bool _isPageScrolling = false;
  bool _isExitRecommendationHistoryLoading = true;
  bool _hasShownExitRecommendationForDrama = false;
  bool _didRecordFirstBuild = false;
  bool _allowRemoteResumeEpisodeSwitch = true;
  bool _enforceInitialHandoffRewindSeek = false;
  bool _isExitRecommendationRequestInFlight = false;
  DateTime? _lastForYouNoMoreToastAt;
  String? _activeCoinSheetItemId;
  String? _activeRechargeSheetItemId;
  String? _lockedNextRewoundCompletionItemId;
  final Set<String> _exitRecommendationEpisodeIds = <String>{};
  CancelToken? _exitRecommendationCancelToken;
  List<PopupExitRecommendation>? _exitRecommendationRecommendations;
  int? _exitRecommendationPopupId;
  AppLifecycleState _previousLifecycleState = AppLifecycleState.resumed;
  bool _wasPlayingBeforeInactive = false;
  bool _resumePlaybackOnLifecycleResume = false;
  bool _resumePlaybackOnRouteReturn = false;
  bool _isCoveredByAnotherRoute = false;
  ModalRoute<dynamic>? _route;
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

  bool get _shouldIgnoreRouteListener => _isLeavingRoute || !mounted;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) {
      return;
    }
    if (_route != null) {
      playerRouteObserver.unsubscribe(this);
    }
    _route = route;
    if (route != null) {
      playerRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (_isLeavingRoute) {
      return;
    }
    _isCoveredByAnotherRoute = true;
    final playback = ref.read(playerPlaybackControllerProvider(_sessionKey));
    _resumePlaybackOnRouteReturn = playback.isPlaying;
    unawaited(_playbackController.pauseForVisibility());
  }

  @override
  void didPopNext() {
    _isCoveredByAnotherRoute = false;
    if (!_resumePlaybackOnRouteReturn ||
        _previousLifecycleState != AppLifecycleState.resumed ||
        _isLeavingRoute) {
      return;
    }
    _resumePlaybackOnRouteReturn = false;
    unawaited(_resumePlaybackAfterLifecyclePause());
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
    _exitRecommendationRecommendations =
        widget.initialExitRecommendationsForTesting;
    _exitRecommendationPopupId =
        widget.initialExitRecommendationPopupIdForTesting;
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
    _playbackController.recordPlaybackTiming(
      'player page initState complete',
      details: [
        'feedMode=${widget.feedMode.name}',
        'trigger=${widget.initialPlaybackTrigger ?? 'player_route_enter'}',
        'hasUserActionAt=${widget.initialUserActionAt != null}',
      ].join(' '),
    );
    if (widget.hideShellNavigation) {
      _shellChrome = ref.read(appShellBottomNavigationVisibleProvider.notifier);
    }
    unawaited(_loadExitRecommendationHistoryState());
    Future<void>.microtask(() async {
      final startupStopwatch = Stopwatch()..start();
      _playbackController.recordPlaybackTiming(
        'player startup microtask start',
        details: 'feedMode=${widget.feedMode.name}',
      );
      _shellChrome?.hide();
      // await ref.read(entitlementControllerProvider.notifier).load();
      if (!mounted) {
        return;
      }
      await _releaseForYouDecoderBeforeSinglePlayback();
      if (!mounted) {
        return;
      }
      _playbackController.recordPlaybackTiming(
        'player startup after competing decoder release',
        elapsed: startupStopwatch.elapsed,
        details: 'feedMode=${widget.feedMode.name}',
      );
      final remoteResumeFuture = widget.forYouHandoff == null
          ? _loadRemoteResumeProgress()
          : null;

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
      if (widget.feedMode == PlayerFeedMode.singleDrama &&
          widget.dramaId != null) {
        final likeController = ref.read(
          playerLikeControllerProvider(widget.dramaId!).notifier,
        );
        unawaited(likeController.refreshLikeStatus());
      }

      await _loadFeedForTiming(remoteResumeFuture: remoteResumeFuture);
      _playbackController.recordPlaybackTiming(
        'player startup microtask end',
        elapsed: startupStopwatch.elapsed,
        details: 'feedMode=${widget.feedMode.name}',
      );
    });
  }

  Future<void> _releaseForYouDecoderBeforeSinglePlayback() async {
    if (widget.feedMode != PlayerFeedMode.singleDrama) return;
    if (!ref
        .read(playerSessionRegistryProvider)
        .contains(PlayerPlaybackSessionKeys.forYouTab)) {
      _playbackController.recordPlaybackTiming(
        'release competing forYou decoder skipped',
        details: 'reason=no_for_you_session',
      );
      return;
    }
    final stopwatch = Stopwatch()..start();
    _playbackController.recordPlaybackTiming(
      'release competing forYou decoder start',
    );
    await ref
        .read(
          playerPlaybackControllerProvider(
            PlayerPlaybackSessionKeys.forYouTab,
          ).notifier,
        )
        .suspendForCompetingPlayer();
    _playbackController.recordPlaybackTiming(
      'release competing forYou decoder end',
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  void dispose() {
    // 涓婃姤瑙傜湅閫€鍑轰簨浠?
    unawaited(_playbackController.reportWatchProgress(eventType: 4));
    WidgetsBinding.instance.removeObserver(this);
    playerRouteObserver.unsubscribe(this);
    _cancelExitRecommendationRequestIfPending();
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
      // 从外部应用（例如 Facebook 分享页）返回时，恢复播放器可操作的默认
      // chrome；不能只依赖“是否自动续播”，否则暂停状态返回会残留沉浸 UI。
      if (previous != AppLifecycleState.resumed && _isPlaybackViewVisible) {
        _restoreChromeAfterReturningToPlayer();
      }
      // 浠?inactive 鎭㈠锛堝涓嬫媺鐘舵€佹爮鍚庢敹鍥烇級锛岃嫢涔嬪墠姝ｅ湪鎾斁鍒欒嚜鍔ㄦ仮澶?
      final shouldResumePlayback =
          _resumePlaybackOnLifecycleResume ||
          (previous == AppLifecycleState.inactive && _wasPlayingBeforeInactive);
      _resumePlaybackOnLifecycleResume = false;
      _wasPlayingBeforeInactive = false;
      if (shouldResumePlayback && _isPlaybackViewVisible) {
        unawaited(_resumePlaybackAfterLifecyclePause());
      }
      return;
    }
    // 璁板綍杩涘叆 inactive 鍓嶆槸鍚︽鍦ㄦ挱鏀撅紝鐢ㄤ簬鎭㈠鏃跺垽鏂槸鍚﹂渶瑕佽嚜鍔ㄦ挱鏀?
    if (state == AppLifecycleState.inactive) {
      final playback = ref.read(playerPlaybackControllerProvider(_sessionKey));
      _wasPlayingBeforeInactive = playback.isPlaying;
      _resumePlaybackOnLifecycleResume =
          _resumePlaybackOnLifecycleResume ||
          _shouldResumePlaybackWhenForYouReturns(playback) ||
          _wasPlayingBeforeInactive;
      unawaited(_playbackController.pause());
      return;
    }
    // paused/detached锛氬垏鎹㈠埌鍚庡彴锛屽畬鍏ㄦ殏鍋滃苟绉婚櫎瑙嗛鐢婚潰浠ラ噴鏀捐祫婧?
    final playback = ref.read(playerPlaybackControllerProvider(_sessionKey));
    _resumePlaybackOnLifecycleResume =
        _resumePlaybackOnLifecycleResume ||
        _shouldResumePlaybackWhenForYouReturns(playback) ||
        playback.isPlaying;
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

  Future<void> _reloadForYouAfterLanguageChange() async {
    if (_isReloadingForYouAfterLanguageChange ||
        widget.feedMode != PlayerFeedMode.forYou) {
      return;
    }
    // For You lives in StatefulShell's indexed stack.  Its widget can receive
    // locale updates while another tab is on screen, so loading the replacement
    // feed here would settle a viewport and issue a new autoplay command behind
    // that tab.  Defer the reload until the player is visible again.
    if (!_isPlaybackViewVisible) {
      _hasPendingForYouLanguageReload = true;
      return;
    }
    _isReloadingForYouAfterLanguageChange = true;
    try {
      await _playbackController.pauseForVisibility();
      if (!mounted) {
        return;
      }
      ref.invalidate(playerViewportControllerProvider(_sessionKey));
      await _loadFeedForTiming();
      // The user may leave For You while the feed request is in flight.  The
      // reload can have started playback before that navigation is observed by
      // the shell, so make the hidden state authoritative one more time.
      if (!_isPlaybackViewVisible) {
        _hasPendingForYouLanguageReload = true;
        await _playbackController.pauseForVisibility();
      }
    } finally {
      _isReloadingForYouAfterLanguageChange = false;
    }
  }

  void _reloadPendingForYouLanguageChangeOnReturn() {
    if (!_hasPendingForYouLanguageReload ||
        widget.feedMode != PlayerFeedMode.forYou ||
        !_isPlaybackViewVisible) {
      return;
    }
    _hasPendingForYouLanguageReload = false;
    unawaited(_reloadForYouAfterLanguageChange());
  }

  bool _shouldResumePlaybackWhenForYouReturns(PlayerPlaybackState playback) {
    if (widget.feedMode != PlayerFeedMode.forYou) {
      return false;
    }
    return playback.currentSource != null || playback.isOpening;
  }

  bool get _isPlaybackViewVisible {
    if (_isCoveredByAnotherRoute) {
      return false;
    }
    if (widget.feedMode != PlayerFeedMode.forYou) {
      return true;
    }
    return ref.read(appShellCurrentTabIndexProvider) ==
        AppShellDestinations.forYouIndex;
  }

  void _restoreChromeAfterReturningToPlayer() {
    if (widget.feedMode != PlayerFeedMode.singleDrama) {
      return;
    }
    _showDefaultChromeAndSyncImmersiveBlockers();
  }

  void _showDefaultChromeAndSyncImmersiveBlockers() {
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
      _playbackController.recordPlaybackTiming(
        'remote resume skipped',
        details: [
          'feedMode=${widget.feedMode.name}',
          'hasDramaId=${widget.dramaId != null}',
          'hasHandoff=${widget.forYouHandoff != null}',
          'useRemote=${ref.read(useRemotePlayerApiProvider)}',
        ].join(' '),
      );
      return;
    }
    final dramaId = int.tryParse(widget.dramaId!);
    if (dramaId == null) {
      _playbackController.recordPlaybackTiming(
        'remote resume skipped',
        details: 'reason=invalid_drama_id dramaId=${widget.dramaId}',
      );
      return;
    }
    final stopwatch = Stopwatch()..start();
    _playbackController.recordPlaybackTiming(
      'remote resume fetch start',
      details: 'dramaId=$dramaId',
    );
    try {
      final watchProgress = await ref
          .read(playerRemoteDataSourceProvider)
          .fetchWatchProgress(dramaId: dramaId);
      _playbackController.recordPlaybackTiming(
        'remote resume fetch end',
        elapsed: stopwatch.elapsed,
        details: [
          'dramaId=$dramaId',
          'hasProgress=${watchProgress != null}',
          if (watchProgress != null) 'episodeId=${watchProgress.episodeId}',
          if (watchProgress != null) 'watchSecond=${watchProgress.watchSecond}',
          if (watchProgress != null)
            'durationSecond=${watchProgress.durationSecond}',
        ].join(' '),
      );
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
      _playbackController.recordPlaybackTiming(
        'remote resume fetch failed',
        elapsed: stopwatch.elapsed,
        error: error,
        details: 'dramaId=$dramaId',
      );
      developer.log('Failed to fetch watch progress: $error', error: error);
    }
  }

  Future<void> _loadFeedForTiming({Future<void>? remoteResumeFuture}) async {
    final feedProvider = playerFeedControllerProvider(_sessionKey);
    final feedController = ref.read(feedProvider.notifier);
    var remoteResumeTimedOut = false;
    if (remoteResumeFuture != null) {
      final waitStopwatch = Stopwatch()..start();
      _playbackController.recordPlaybackTiming('remote resume wait start');
      await remoteResumeFuture.timeout(
        _remoteResumeInitialWait,
        onTimeout: () {
          remoteResumeTimedOut = true;
        },
      );
      _playbackController.recordPlaybackTiming(
        remoteResumeTimedOut
            ? 'remote resume wait timeout'
            : 'remote resume wait end',
        elapsed: waitStopwatch.elapsed,
        details: 'budgetMs=${_remoteResumeInitialWait.inMilliseconds}',
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
        if (remoteResumeTimedOut && remoteResumeFuture != null) {
          unawaited(_applyLateRemoteResumeProgress(remoteResumeFuture));
        }
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
        _playbackController.setPendingResumeProgress(
          _resumeProgress,
          requireSeekAfterOpen: _enforceInitialHandoffRewindSeek,
        );
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

  Future<void> _applyLateRemoteResumeProgress(Future<void> resumeFuture) async {
    await resumeFuture;
    if (!mounted || _startupRemoteWatchProgress == null) {
      return;
    }
    _playbackController.recordPlaybackTiming('remote resume late apply start');
    await _applyStartupRemoteResumeProgress(
      ref.read(playerFeedControllerProvider(_sessionKey)),
    );
    _playbackController.recordPlaybackTiming('remote resume late apply end');
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
    // The handoff only owns the intent (For You completed). The normal player
    // owns the episode timeline, so calculate its rewind from the normal feed
    // duration instead of reusing a potentially different For You HLS length.
    final duration = targetItem.episode.duration ?? handoff.duration;
    final shouldRewindBeforeLockedNext =
        handoff.rewoundFromCompletion &&
        _shouldRewindBeforeLockedNext(item: targetItem, feedState: feedState);
    final normalizedPosition = shouldRewindBeforeLockedNext
        ? _rewindPositionBeforeEnd(duration)
        : handoff.position;
    final progress = PlaybackProgress(
      itemId: targetItem.id,
      position: normalizedPosition,
      duration: duration,
      updatedAt: DateTime.now(),
    );
    _enforceInitialHandoffRewindSeek = shouldRewindBeforeLockedNext;
    if (shouldRewindBeforeLockedNext) {
      _lockedNextRewoundCompletionItemId = targetItem.id;
    }
    _resumeProgress = progress;
    if (progress.canResume) {
      _playbackController.setPendingResumeProgress(
        progress,
        requireSeekAfterOpen: shouldRewindBeforeLockedNext,
      );
    }
  }

  bool _shouldRewindBeforeLockedNext({
    required PlayerFeedItem item,
    required PlayerFeedState feedState,
  }) {
    final itemIndex = feedState.items.indexWhere(
      (candidate) => candidate.id == item.id,
    );
    if (itemIndex == -1 || itemIndex + 1 >= feedState.items.length) {
      return false;
    }
    return _feedEngine.accessPresentationFor(feedState.items[itemIndex + 1]) !=
        PlayerAccessPresentationState.playable;
  }

  Duration _rewindPositionBeforeEnd(Duration duration) {
    if (duration <= _lockedNextEpisodeRewind) {
      return Duration.zero;
    }
    return duration - _lockedNextEpisodeRewind;
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
    var resumePosition = canResume ? remotePosition : Duration.zero;
    var resumeDuration = canResume ? remoteDuration : Duration.zero;
    if (!canResume && remoteItemIndex + 1 < feedState.items.length) {
      final nextItem = feedState.items[remoteItemIndex + 1];
      final shouldRewindBeforeLockedNext =
          widget.feedMode == PlayerFeedMode.singleDrama &&
          remoteDuration > Duration.zero &&
          _feedEngine.accessPresentationFor(nextItem) !=
              PlayerAccessPresentationState.playable;
      if (shouldRewindBeforeLockedNext) {
        targetIndex = remoteItemIndex;
        resumePosition = remoteDuration > _lockedNextEpisodeRewind
            ? remoteDuration - _lockedNextEpisodeRewind
            : Duration.zero;
        resumeDuration = remoteDuration;
        _lockedNextRewoundCompletionItemId =
            feedState.items[remoteItemIndex].id;
      } else {
        targetIndex = remoteItemIndex + 1;
      }
    }

    final targetItem = feedState.items[targetIndex];
    final progress = PlaybackProgress(
      itemId: targetItem.id,
      position: resumePosition,
      duration: resumeDuration,
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
    final subtitleState = ref.watch(
      playerPlaybackControllerProvider(sessionKey).select(
        (state) => (
          subtitles: state.availableSubtitles,
          episodeSources: state.availableEpisodeSources,
          currentLanguage: state.currentSubtitleLanguage,
          isSelectionResolved: state.isSubtitleSelectionResolved,
        ),
      ),
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

    ref.listen(appLocaleControllerProvider.select(apiLangFromLocale), (
      previous,
      next,
    ) {
      if (widget.feedMode != PlayerFeedMode.forYou ||
          previous == null ||
          previous == next) {
        return;
      }
      unawaited(_reloadForYouAfterLanguageChange());
    });

    // A locale change may have occurred while this indexed-stack page was
    // hidden.  Refresh only after navigation makes the player visible, which
    // keeps the feed current without allowing background audio.
    ref.listen(appShellCurrentTabIndexProvider, (previous, next) {
      if (next == AppShellDestinations.forYouIndex) {
        _reloadPendingForYouLanguageChangeOnReturn();
      }
    });

    ref.listen(
      viewportProvider.select(PlayerViewportSettledSnapshot.fromState),
      (previous, next) {
        if (_shouldIgnoreRouteListener) {
          return;
        }
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
              position: _forYouResumePosition(cached.position, cached.duration),
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
        if (_shouldIgnoreRouteListener) {
          return;
        }
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
      if (_shouldIgnoreRouteListener) {
        return;
      }
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
          if (_shouldIgnoreRouteListener) {
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
          if (_shouldIgnoreRouteListener) {
            return;
          }
          _syncAutoImmersiveBlockers();
        },
      );
      ref.listen(viewportProvider.select((state) => state.scrollPhase), (
        previous,
        next,
      ) {
        if (_shouldIgnoreRouteListener) {
          return;
        }
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
        if (_shouldIgnoreRouteListener) {
          return;
        }
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
      ).select((state) => (state.currentItemId, state.hasFirstFrame)),
      (previous, next) {
        if (_shouldIgnoreRouteListener) {
          return;
        }
        if (next.$1 == null || !next.$2) {
          return;
        }
        _recordExitRecommendationEpisode(itemId: next.$1!);
      },
    );

    ref.listen(
      playerPlaybackControllerProvider(
        sessionKey,
      ).select((state) => (state.currentItemId, state.hasEnded)),
      (previous, next) {
        if (_shouldIgnoreRouteListener) {
          return;
        }
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
        } else {
          unawaited(_advanceToNextFromCompletion(completedItemId: next.$1!));
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
          subtitles: subtitleState.subtitles,
          episodeSources: subtitleState.episodeSources,
          currentSubtitleLanguage: subtitleState.currentLanguage,
          isSubtitleSelectionResolved: subtitleState.isSelectionResolved,
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
    required List<PlayerSubtitle> subtitles,
    required List<PlayerEpisodeSource> episodeSources,
    required String? currentSubtitleLanguage,
    required bool isSubtitleSelectionResolved,
    required PlayerPlaybackController playbackController,
    required PlayerFeedEngine feedEngine,
    required PlayerPerformancePolicy performancePolicy,
    required bool showsChromeOverlays,
    required Duration chromeOverlayFadeDuration,
    required PlayerUiController uiController,
  }) {
    Future<void> refreshFeed() {
      return widget.feedMode == PlayerFeedMode.forYou
          ? _refreshForYouFeed()
          : Future<void>.value();
    }

    if (isLoading && items.isEmpty) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null && items.isEmpty) {
      final stateMessage = PlayerStateMessage(
        icon: Icons.refresh_rounded,
        message: context.l10n.playerFeedLoadFailed,
        actionLabel: context.l10n.retry,
        onAction: feedController.retry,
      );
      if (widget.feedMode != PlayerFeedMode.forYou) {
        return stateMessage;
      }
      return _ForYouRefreshableState(
        onRefresh: refreshFeed,
        child: stateMessage,
      );
    }
    if (items.isEmpty) {
      final stateMessage = PlayerStateMessage(
        icon: Icons.movie_filter_rounded,
        message: widget.feedMode == PlayerFeedMode.forYou
            ? context.l10n.recommendTabEmptyNoContent
            : context.l10n.playerNoEpisodes,
      );
      if (widget.feedMode != PlayerFeedMode.forYou) {
        return stateMessage;
      }
      return _ForYouRefreshableState(
        onRefresh: refreshFeed,
        child: stateMessage,
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

    final pageView = Listener(
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
          // For You 到底时不能追加一个整屏“暂无数据” page。它会让用户看起来像
          // 滑进了空白内容，也与首页/My List 的底部 footer 不一致。
          itemCount: items.length,
          onPageChanged: (index) {
            feedEngine.onPageChanged(index);
            if (widget.feedMode == PlayerFeedMode.forYou &&
                index == items.length - 1) {
              final latestFeed = ref.read(
                playerFeedControllerProvider(_sessionKey),
              );
              if (latestFeed.hasMore) {
                unawaited(feedController.loadMore());
              } else {
                _showForYouNoMoreToast();
              }
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
              onTogglePlay: ({required pauseRequested}) {
                unawaited(
                  playbackController.togglePlay(pauseRequested: pauseRequested),
                );
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
                unawaited(_openForYouItemInPlayer(item, rewindFromEnd: false));
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
              onShareTap: () =>
                  _showShareSheet(item.content.id, item.content.title),
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
    );

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
        widget.feedMode == PlayerFeedMode.forYou
            ? RefreshIndicator(onRefresh: refreshFeed, child: pageView)
            : pageView,
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
                showChromeOverlays: showsChromeOverlays,
                overlayOpacityListenable:
                    performancePolicy.allowPressChromeDimming
                    ? _overlayOpacityNotifier
                    : null,
                onBackTap: () {
                  unawaited(_goBackFromPlayer());
                },
                onSpeedTap: _showSpeedSheet,
                subtitles: subtitles,
                episodeSources: episodeSources,
                currentSubtitleLanguage: currentSubtitleLanguage,
                isSubtitleSelectionResolved: isSubtitleSelectionResolved,
                showSubtitleEntry:
                    viewportState.scrollPhase == PlayerViewportScrollPhase.idle,
                onSubtitleSelected: (language) {
                  final controller = ref.read(
                    playerPlaybackControllerProvider(_sessionKey).notifier,
                  );
                  unawaited(
                    language == null
                        ? controller.setSubtitle(null)
                        : controller.selectSubtitleLanguage(language),
                  );
                },
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

  Future<void> _refreshForYouFeed() async {
    if (_isRefreshingForYouFeed ||
        widget.feedMode != PlayerFeedMode.forYou ||
        !mounted) {
      return;
    }
    _isRefreshingForYouFeed = true;
    try {
      await ref
          .read(playerFeedControllerProvider(_sessionKey).notifier)
          .refresh();
      if (!mounted) {
        return;
      }
      final refreshedFeed = ref.read(playerFeedControllerProvider(_sessionKey));
      if (refreshedFeed.items.isEmpty) {
        return;
      }
      // Refresh starts a new For You feed at its first item. Align the page
      // and viewport in the same event turn, before Flutter has a chance to
      // rebuild the overlay against an old item id and drop its Video surface.
      const firstIndex = 0;
      final firstItem = refreshedFeed.items[firstIndex];
      if (_pageController.hasClients &&
          _pageController.page?.round() != firstIndex) {
        _pageController.jumpToPage(firstIndex);
      }
      _feedEngine.initializeViewport(index: firstIndex, itemId: firstItem.id);
      _syncActiveVideoPagePosition();
    } finally {
      _isRefreshingForYouFeed = false;
    }
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
    if (notification is OverscrollNotification &&
        widget.feedMode == PlayerFeedMode.forYou &&
        notification.overscroll > 0) {
      final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
      if (!feedState.hasMore &&
          notification.metrics.pixels >= notification.metrics.maxScrollExtent) {
        _showForYouNoMoreToast();
      }
    }
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

  void _showForYouNoMoreToast() {
    final now = DateTime.now();
    final lastShownAt = _lastForYouNoMoreToastAt;
    // 一次上滑会发出多个 Overscroll 通知；短暂去重，避免同一手势连弹 toast。
    if (lastShownAt != null &&
        now.difference(lastShownAt) < const Duration(seconds: 2)) {
      return;
    }
    _lastForYouNoMoreToastAt = now;
    showAppCenterToast(context.l10n.feedNoMore);
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

    _isOpeningForYouPlayer = true;
    try {
      final effectiveDuration = playbackState.duration > Duration.zero
          ? playbackState.duration
          : item.episode.duration ?? Duration.zero;
      final shouldUseCurrentPlayback = isCurrentPlayableItem;
      final targetEpisodeId = shouldUseCurrentPlayback ? item.episode.id : '1';
      final initialPosition = shouldUseCurrentPlayback
          ? rewindFromEnd
                ? Duration(
                    milliseconds: (effectiveDuration - _lockedNextEpisodeRewind)
                        .inMilliseconds
                        .clamp(0, effectiveDuration.inMilliseconds),
                  )
                : playbackState.position
          : Duration.zero;
      final handoff = ForYouPlayerHandoff(
        id: '${item.id}:${DateTime.now().microsecondsSinceEpoch}',
        originItemId: item.id,
        dramaId: item.content.id,
        episodeId: targetEpisodeId,
        position: initialPosition,
        duration: shouldUseCurrentPlayback ? effectiveDuration : Duration.zero,
        rewoundFromCompletion: rewindFromEnd,
      );
      ref
          .read(forYouPlaybackProgressControllerProvider.notifier)
          .save(
            ForYouPlaybackSnapshot(
              originItemId: item.id,
              dramaId: item.content.id,
              episode: item.episode,
              position: initialPosition,
              duration: shouldUseCurrentPlayback
                  ? effectiveDuration
                  : Duration.zero,
              updatedAt: DateTime.now(),
            ),
          );
      if (shouldUseCurrentPlayback) {
        unawaited(_playbackController.pauseForRouteHandoff());
      } else {
        unawaited(_playbackController.pauseForVisibility(syncState: false));
      }
      if (!mounted) {
        return;
      }
      final location = RoutePaths.playerLocation(
        dramaId: item.content.id,
        episodeId: targetEpisodeId,
        trigger: rewindFromEnd ? 'for_you_complete' : 'for_you_watch_now',
        userActionAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      unawaited(
        context.push<ForYouPlaybackSnapshot>(location, extra: handoff).then((
          returned,
        ) async {
          if (!mounted || returned == null) {
            return;
          }
          ref
              .read(forYouPlaybackProgressControllerProvider.notifier)
              .save(returned);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) {
            return;
          }
          await _synchronizeReturnedForYouProgress(returned);
        }),
      );
      if (!mounted) {
        return;
      }
    } finally {
      _isOpeningForYouPlayer = false;
    }
  }

  Duration _forYouResumePosition(Duration position, Duration duration) {
    if (duration > Duration.zero &&
        position >= duration - _forYouNearEndRestartThreshold) {
      return Duration.zero;
    }
    return position;
  }

  Future<void> _advanceToNextFromCompletion({
    required String completedItemId,
  }) async {
    if (_isAutoAdvancing || !mounted) {
      return;
    }
    final feedProvider = playerFeedControllerProvider(_sessionKey);
    final feedState = ref.read(feedProvider);
    if (!feedState.canGoNext) {
      _clearLockedNextRewind(completedItemId);
      return;
    }
    final nextIndex = feedState.currentIndex + 1;
    final nextItem = feedState.items[nextIndex];
    _clearLockedNextRewind(completedItemId);
    _isAutoAdvancing = true;
    try {
      _playbackController.recordPlaybackUserAction(
        'auto next animation start',
        trigger: 'auto_next',
        fromItemId: feedState.currentItem?.id,
        toItemId: nextItem.id,
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
          .settle(index: nextIndex, itemId: nextItem.id);
    } finally {
      _isAutoAdvancing = false;
    }
  }

  void _clearLockedNextRewind(String itemId) {
    if (_lockedNextRewoundCompletionItemId == itemId) {
      _lockedNextRewoundCompletionItemId = null;
    }
  }

  Future<void> _goBackFromPlayer({bool skipExitRecommendation = false}) async {
    if (!skipExitRecommendation && await _showExitRecommendationIfAvailable()) {
      return;
    }
    _cancelExitRecommendationRequestIfPending();
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
    _isLeavingRoute = true;
    if (context.canPop()) {
      context.pop(handoffResult);
    } else {
      context.go(RoutePaths.home);
    }
  }

  void _recordExitRecommendationEpisode({required String itemId}) {
    if (widget.feedMode != PlayerFeedMode.singleDrama ||
        widget.dramaId == null ||
        _isExitRecommendationHistoryLoading ||
        _hasShownExitRecommendationForDrama) {
      return;
    }
    final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    PlayerFeedItem? playingItem;
    for (final candidate in feedState.items) {
      if (candidate.id == itemId) {
        playingItem = candidate;
        break;
      }
    }
    if (playingItem == null || playingItem.content.id != widget.dramaId) {
      return;
    }
    _exitRecommendationEpisodeIds.add(playingItem.episode.id);
    if (_exitRecommendationEpisodeIds.length >= 2) {
      _startExitRecommendationRequestIfEligible();
    }
  }

  void _startExitRecommendationRequestIfEligible() {
    if (widget.feedMode != PlayerFeedMode.singleDrama ||
        widget.dramaId == null ||
        _isExitRecommendationHistoryLoading ||
        _hasShownExitRecommendationForDrama ||
        _isExitRecommendationRequestInFlight ||
        _exitRecommendationRecommendations != null ||
        _exitRecommendationEpisodeIds.length < 2) {
      return;
    }
    _isExitRecommendationRequestInFlight = true;
    final cancelToken = CancelToken();
    _exitRecommendationCancelToken = cancelToken;
    unawaited(_loadExitRecommendation(cancelToken));
  }

  Future<void> _loadExitRecommendation(CancelToken cancelToken) async {
    try {
      final recommendationSet = await ref
          .read(popupRepositoryProvider)
          .fetchDetailExitRecommendations(
            dramaId: widget.dramaId!,
            cancelToken: cancelToken,
          );
      if (cancelToken.isCancelled) {
        return;
      }
      final recommendations = recommendationSet.recommendations;
      if (recommendations.length >= 5) {
        _exitRecommendationRecommendations = recommendations;
        _exitRecommendationPopupId = recommendationSet.popupId;
      }
      debugPrint(
        '[PopupExitRecommendation] Loaded ${recommendations.length} '
        'items for drama ${widget.dramaId}.',
      );
    } catch (error) {
      if (error is ApiException && error.code == ApiErrorCode.cancelled) {
        return;
      }
      debugPrint(
        '[PopupExitRecommendation] Request failed for drama '
        '${widget.dramaId}: $error',
      );
    } finally {
      if (_exitRecommendationCancelToken == cancelToken) {
        _exitRecommendationCancelToken = null;
      }
      _isExitRecommendationRequestInFlight = false;
    }
  }

  void _cancelExitRecommendationRequestIfPending() {
    final cancelToken = _exitRecommendationCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      return;
    }
    cancelToken.cancel('player exiting before exit recommendation loaded');
  }

  Future<bool> _showExitRecommendationIfAvailable() async {
    if (widget.feedMode != PlayerFeedMode.singleDrama ||
        _isModalOpen ||
        _hasShownExitRecommendationForDrama) {
      return false;
    }
    final recommendations = _exitRecommendationRecommendations;
    if (recommendations == null || recommendations.length < 5 || !mounted) {
      return false;
    }

    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    _markExitRecommendationShown();
    // TODO: Enable if player exit recommendation popup show reporting is required.
    // _reportExitRecommendationShowIfNeeded();
    final result = await showGeneralDialog<_ExitRecommendationDialogResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Exit recommendation',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PlayerExitRecommendationDialog(
          recommendations: recommendations,
          onExit: () => Navigator.of(
            dialogContext,
          ).pop(const _ExitRecommendationExitResult()),
          onPlay: (recommendation) {
            Navigator.of(
              dialogContext,
            ).pop(_ExitRecommendationPlayResult(recommendation));
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );

    if (!mounted) {
      return true;
    }
    _isModalOpen = false;
    _syncAutoImmersiveBlockers();
    switch (result) {
      case _ExitRecommendationExitResult():
        unawaited(_goBackFromPlayer(skipExitRecommendation: true));
      case _ExitRecommendationPlayResult(:final recommendation):
        _openRecommendationFromExitDialog(recommendation);
      case null:
    }
    return true;
  }

  Future<void> _loadExitRecommendationHistoryState() async {
    final dramaId = widget.dramaId;
    if (widget.feedMode != PlayerFeedMode.singleDrama || dramaId == null) {
      _isExitRecommendationHistoryLoading = false;
      return;
    }
    final userKey = _exitRecommendationUserKey(
      ref.read(authControllerProvider).session,
    );
    try {
      final hasShown = await ref
          .read(playerExitRecommendationHistoryRepositoryProvider)
          .hasShown(userKey: userKey, dramaId: dramaId);
      if (!mounted) {
        return;
      }
      _hasShownExitRecommendationForDrama = hasShown;
      if (hasShown) {
        _cancelExitRecommendationRequestIfPending();
      }
    } catch (error) {
      debugPrint(
        '[PopupExitRecommendation] History read failed for drama '
        '$dramaId: $error',
      );
    } finally {
      if (mounted) {
        _isExitRecommendationHistoryLoading = false;
        _startExitRecommendationRequestIfEligible();
      }
    }
  }

  void _markExitRecommendationShown() {
    final dramaId = widget.dramaId;
    if (dramaId == null || _hasShownExitRecommendationForDrama) {
      return;
    }
    _hasShownExitRecommendationForDrama = true;
    final userKey = _exitRecommendationUserKey(
      ref.read(authControllerProvider).session,
    );
    unawaited(
      ref
          .read(playerExitRecommendationHistoryRepositoryProvider)
          .markShown(userKey: userKey, dramaId: dramaId),
    );
  }

  static String _exitRecommendationUserKey(AuthSession session) {
    final userId = session.user?.id.trim();
    if (userId != null && userId.isNotEmpty) {
      return 'user:$userId';
    }
    final guestId = session.guestId?.trim();
    if (guestId != null && guestId.isNotEmpty) {
      return 'guest:$guestId';
    }
    final sessionId = session.sessionId?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      return 'session:$sessionId';
    }
    return 'anonymous';
  }

  void _openRecommendationFromExitDialog(
    PopupExitRecommendation recommendation,
  ) {
    _cancelExitRecommendationRequestIfPending();
    _isLeavingRoute = true;
    final location = RoutePaths.playerLocation(
      dramaId: '${recommendation.id}',
      episodeId: '1',
      trigger: 'exit_recommendation',
      userActionAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    context.pushReplacement(location);
  }

  // ignore: unused_element
  void _reportExitRecommendationShowIfNeeded() {
    final popupId = _exitRecommendationPopupId;
    if (popupId == null) {
      return;
    }
    unawaited(() async {
      try {
        await ref
            .read(popupRepositoryProvider)
            .reportPopupEvent(popupId: popupId, eventType: PopupEventType.show);
      } catch (error) {
        debugPrint(
          '[PopupExitRecommendation] Show event report failed for '
          '$popupId: $error',
        );
      }
    }());
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
      if (currentItem != null) {
        final snapshot = _forYouReturnSnapshotForItem(
          currentItem: currentItem,
          feed: feed,
          position: playback.position,
          duration: playback.duration,
        );
        ref
            .read(forYouPlaybackProgressControllerProvider.notifier)
            .save(snapshot);
        return snapshot;
      }
      return ref
          .read(forYouPlaybackProgressControllerProvider.notifier)
          .snapshotFor(handoff.dramaId);
    }
    final snapshot = _forYouReturnSnapshotForItem(
      currentItem: currentItem,
      feed: feed,
      position: playback.position,
      duration: playback.duration,
    );
    ref.read(forYouPlaybackProgressControllerProvider.notifier).save(snapshot);
    return snapshot;
  }

  ForYouPlaybackSnapshot _forYouReturnSnapshotForItem({
    required PlayerFeedItem currentItem,
    required PlayerFeedState feed,
    required Duration position,
    required Duration duration,
  }) {
    final handoff = widget.forYouHandoff!;
    var targetItem = currentItem;
    var targetPosition = position;
    var targetDuration = duration > Duration.zero
        ? duration
        : currentItem.episode.duration ?? Duration.zero;
    if (_feedEngine.accessPresentationFor(currentItem) !=
        PlayerAccessPresentationState.playable) {
      final currentIndex = feed.items.indexWhere(
        (item) => item.id == currentItem.id,
      );
      if (currentIndex > 0) {
        targetItem = feed.items[currentIndex - 1];
        targetPosition = Duration.zero;
        targetDuration = targetItem.episode.duration ?? Duration.zero;
      }
    }
    return ForYouPlaybackSnapshot(
      originItemId: handoff.originItemId,
      dramaId: targetItem.content.id,
      episode: targetItem.episode,
      position: _forYouResumePosition(targetPosition, targetDuration),
      duration: targetDuration,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _openRecommendationFromDetailSheet(
    PlayerRecommendation recommendation,
  ) async {
    if (_isOpeningRecommendation) {
      return;
    }
    _isOpeningRecommendation = true;
    try {
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
      if (_isModalOpen) {
        _showDefaultChromeAndSyncImmersiveBlockers();
      } else {
        _restoreChromeAfterReturningToPlayer();
      }
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
            final currentItem = ref
                .read(playerFeedControllerProvider(_sessionKey))
                .currentItem;
            return PlayerDetailSheet(
              content: displayContent,
              initialTab: initialTab,
              currentEpisode: currentItem?.episode.number ?? 1,
              currentEpisodeId: currentItem?.episode.id,
              onEpisodeSelected: (episode) {
                _closeSheetAndSelectEpisode(sheetContext, episode);
              },
              onRecommendationSelected: (recommendation) {
                unawaited(_openRecommendationFromDetailSheet(recommendation));
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

  Future<void> _showShareSheet(String dramaId, String dramaTitle) {
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => PlayerShareSheet(
        onFacebookTap: () {
          unawaited(_reportDramaShareAction(dramaId, 'facebook'));
          unawaited(_shareToFacebook(dramaId, dramaTitle));
        },
        onCopyLinkTap: () {
          unawaited(_reportDramaShareAction(dramaId, 'copy_link'));
          unawaited(_copyShareLink(dramaId, dramaTitle));
        },
      ),
    ).whenComplete(() {
      _isModalOpen = false;
      if (mounted) {
        _syncAutoImmersiveBlockers();
      }
    });
  }

  Future<void> _reportDramaShareAction(
    String dramaId,
    String shareChannel,
  ) async {
    try {
      await ref
          .read(playerRemoteDataSourceProvider)
          .reportDramaShareAction(dramaId: dramaId, shareChannel: shareChannel);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to report drama share action.',
        name: 'PlayerShare',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _shareToFacebook(String dramaId, String dramaTitle) async {
    final shareUrl = _shareUrl(dramaId);
    final shareMessage = _shareMessage(dramaTitle, shareUrl);
    final facebookShareUrl = Uri.https(
      'www.facebook.com',
      '/sharer/sharer.php',
      {'u': shareUrl.toString(), 'quote': shareMessage},
    );
    final opened = await ref
        .read(externalUrlLauncherProvider)
        .open(facebookShareUrl.toString());
    if (!opened) {
      debugPrint(
        '[PlayerShare] Failed to open Facebook share: $facebookShareUrl',
      );
    }
  }

  Uri _shareUrl(String dramaId) {
    final languageCode = ref.read(appLocaleControllerProvider).languageCode;
    return AppConfig.current.shareUrl(
      dramaId: dramaId,
      languageCode: languageCode,
    );
  }

  String _shareMessage(String dramaTitle, Uri shareUrl) {
    return context.l10n.shareMessage(
      dramaTitle: dramaTitle,
      shareUrl: shareUrl.toString(),
    );
  }

  Future<void> _copyShareLink(String dramaId, String dramaTitle) async {
    final shareMessage = _shareMessage(dramaTitle, _shareUrl(dramaId));
    await Clipboard.setData(ClipboardData(text: shareMessage));
    if (mounted) {
      showAppCenterToast(context.l10n.shareToastCopySuccess);
    }
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

class _ForYouRefreshableState extends StatelessWidget {
  const _ForYouRefreshableState({required this.onRefresh, required this.child});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
                MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).vertical,
            child: child,
          ),
        ],
      ),
    );
  }
}
