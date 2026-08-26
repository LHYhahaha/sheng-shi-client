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
import '../../../../core/adjust/adjust_event_reporter_provider.dart';
import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/analytics_popup_names.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/user_info_store.dart';
import '../../../../core/channel/channel_config_service.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/logging/app_log.dart' as developer;
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_service.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/locale/app_locale_controller.dart';
import '../../../../core/runtime/api_lang_provider.dart';
import '../../../../core/toast/app_center_toast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/url/external_url_launcher.dart';
import '../../../pay/application/payment_loading_controller.dart';
import '../../../entitlement/application/entitlement_controller.dart';
import '../../../entitlement/domain/episode_unlock_type.dart';
import '../../data/player_exit_recommendation_history_repository_provider.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/auth_session.dart';
import '../../application/player_feed_controller.dart';
import '../../application/player_entry_preload_coordinator.dart';
import '../../application/player_feed_engine.dart';
import '../../application/player_runtime_coordinator.dart';
import '../../application/player_feed_engine_access_flow.dart';
import '../../application/for_you_playback_progress_controller.dart';
import '../../application/player_overlay_orchestrator.dart';
import '../../application/player_performance_policy_provider.dart';
import '../../application/player_playback_controller.dart';
import '../../application/player_recharge_unlock_controller.dart';
import '../../application/player_unlock_modal_coordinator.dart';
import '../../application/player_rebuild_diagnostics.dart';
import '../../application/player_session_registry.dart';
import '../../application/player_ui_controller.dart';
import '../../application/player_viewport_controller.dart';
import '../../data/playback_progress_repository_provider.dart';
import '../../data/drama_playback_target_repository_provider.dart';
import '../../data/player_content_repository_provider.dart';
import '../../data/mapper/player_content_mapper.dart';
import '../../data/player_remote_data_source_provider.dart';
import '../../../popup/data/popup_repository_provider.dart';
import '../../../popup/domain/popup.dart';
import '../../domain/player_access_presentation.dart';
import '../../domain/for_you_player_handoff.dart';
import '../../domain/player_performance_policy.dart';
import '../../domain/player_content.dart';
import '../../domain/player_feed.dart';
import '../../domain/player_playback_progress.dart';
import '../../domain/drama_playback_target.dart';
import '../../domain/player_subtitle.dart';
import '../widgets/player_action_sheets.dart';
import '../widgets/player_detail_sheet.dart';
import '../widgets/player_exit_recommendation_dialog.dart';
import '../widgets/player_feed_page_shell.dart';
import '../widgets/player_chrome.dart';
import '../widgets/player_playback_layer.dart';
import '../../../ad_unlock/application/ad_unlock_session_controller.dart';
import '../../../ad_unlock/application/ad_unlock_analytics_tracker.dart';
import '../../../ad_unlock/application/ad_unlock_popup_analytics.dart';
import '../../../ad_unlock/data/ad_unlock_repository_provider.dart';
import '../../../ad_unlock/domain/ad_unlock_models.dart';
import '../../../ad_unlock/presentation/ad_unlock_page.dart';
import '../../../ad_unlock/presentation/ad_unlock_prompt_dialog.dart';

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

class _InitialResumeCandidate {
  const _InitialResumeCandidate({required this.source, required this.progress});

  final String source;
  final PlayerWatchProgress progress;
}

class _AdUnlockStatusCacheEntry {
  const _AdUnlockStatusCacheEntry({
    required this.status,
    required this.fetchedAt,
  });

  final AdUnlockStatus status;
  final DateTime fetchedAt;
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
  static const _lockedNextEpisodeRewind = Duration(seconds: 8);
  static const _forYouNearEndRestartThreshold = Duration(seconds: 8);
  static const _unlockTapDebounce = Duration(milliseconds: 500);
  static const _predictivePreloadPageThreshold = 0.60;
  static const _adUnlockStatusCacheTtl = Duration(seconds: 30);

  late final PageController _pageController;
  late final String _sessionKey;
  late final PlayerPlaybackController _playbackController;
  late final PlayerOverlayOrchestrator _overlayOrchestrator;
  late final AppModalService _modalService;
  AppShellBottomNavigationVisible? _shellChrome;
  PlaybackProgress? _resumeProgress;
  PlayerWatchProgress? _startupRemoteWatchProgress;
  Future<DramaPlaybackTarget?>? _localResumeTargetFuture;
  String? _initialResumeEpisodeId;
  bool _isSeekDragging = false;
  bool _isModalOpen = false;
  bool _isAutoAdvancing = false;
  bool _isOpeningRecommendation = false;
  bool _isOpeningSearch = false;
  bool _isOpeningForYouPlayer = false;
  bool _isReloadingForYouAfterLanguageChange = false;
  bool _isReloadingForYouAfterSessionRecovery = false;
  bool _hasPendingForYouLanguageReload = false;
  bool _isRefreshingForYouFeed = false;
  bool _isLeavingRoute = false;
  bool _isDisposing = false;
  bool _isPressingPlaybackSurface = false;
  bool _isPageScrolling = false;
  bool _isExitRecommendationHistoryLoading = true;
  bool _hasShownExitRecommendationForDrama = false;
  bool _hasShownDramaTakenDownToast = false;
  bool _didRecordFirstBuild = false;
  bool _allowRemoteResumeEpisodeSwitch = true;
  bool _enforceInitialHandoffRewindSeek = false;
  bool _isExitRecommendationRequestInFlight = false;
  bool _isOpeningUnlockActionSheet = false;
  int? _lastPredictivePreloadIndex;
  DateTime? _lastUnlockTapAt;
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
  String? _pendingAdUnlockedItemId;
  final Map<String, _AdUnlockStatusCacheEntry> _adUnlockStatusCache =
      <String, _AdUnlockStatusCacheEntry>{};
  final Map<String, Future<AdUnlockStatus?>> _adUnlockStatusInFlight =
      <String, Future<AdUnlockStatus?>>{};
  final Map<String, DateTime> _adUnlockUnavailableUntil = <String, DateTime>{};
  bool _isAdMaterialUnavailable = false;
  String? _adMaterialUnavailableMessage;
  String? _analyticsPlayingItemId;
  PlayerFeedItem? _analyticsPlayingItem;
  DateTime? _analyticsPlaybackStartedAt;
  Duration _analyticsPlaybackProgress = Duration.zero;
  String? _analyticsSubtitleLanguage;
  Timer? _analyticsPauseTimer;
  late final AnalyticsService _analyticsService;
  late final ProviderContainer _providerContainer;
  late final AdUnlockEntryExposureTracker _adUnlockEntryExposureTracker;
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

  Future<void> _trackPlaybackStart(String itemId) async {
    if (_analyticsPlayingItemId == itemId) {
      return;
    }
    if (_analyticsPlayingItemId != null) {
      await _trackPlaybackEnd(reason: 'episode_switch');
    }

    final item = _feedItemForId(itemId);
    if (item == null) {
      return;
    }
    _analyticsPlayingItemId = itemId;
    _analyticsPlayingItem = item;
    _analyticsPlaybackStartedAt = DateTime.now();
    final playback = _providerContainer.read(
      playerPlaybackControllerProvider(_sessionKey),
    );
    _analyticsPlaybackProgress = playback.position;
    _analyticsSubtitleLanguage = _subtitleLanguageForAnalytics(playback);
    developer.log(
      'Adjust drama play start requested',
      name: 'PlayerAnalytics',
      error: 'token=x7p5qa itemId=$itemId',
    );
    _providerContainer.read(adjustEventReporterProvider).reportDramaPlayStart();
    await _analyticsService.track(
      AnalyticsEvent(AnalyticsDefinitions.dramaPlayStart, {
        'drama_id': item.content.id,
        'episode_id': item.episode.id,
        'episode_no': item.episode.number,
        'subtitle_language': _analyticsSubtitleLanguage!,
        'viewing_entitlement_type': item.episode.viewingEntitlementType,
      }),
    );
  }

  Future<void> _trackPlaybackEnd({
    required String reason,
    String? itemId,
  }) async {
    _cancelAnalyticsPauseTimer();
    final activeItemId = _analyticsPlayingItemId;
    if (activeItemId == null || (itemId != null && itemId != activeItemId)) {
      return;
    }
    final item = _analyticsPlayingItem;
    _analyticsPlayingItemId = null;
    _analyticsPlayingItem = null;
    final startedAt = _analyticsPlaybackStartedAt;
    _analyticsPlaybackStartedAt = null;
    if (item == null || startedAt == null) {
      return;
    }

    await _analyticsService.track(
      AnalyticsEvent(AnalyticsDefinitions.dramaPlayEnd, {
        'drama_id': item.content.id,
        'episode_id': item.episode.id,
        'episode_no': item.episode.number,
        'play_duration_ms': DateTime.now().difference(startedAt).inMilliseconds,
        'play_progress_ms': _analyticsPlaybackProgress.inMilliseconds,
        'play_end_reason': reason,
        'subtitle_language': _analyticsSubtitleLanguage ?? 'off',
        'viewing_entitlement_type': _currentViewingEntitlementType(item),
      }),
    );
  }

  PlayerFeedItem? _feedItemForId(String itemId) {
    final items = _providerContainer
        .read(playerFeedControllerProvider(_sessionKey))
        .items;
    for (final item in items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }

  String _currentViewingEntitlementType(PlayerFeedItem startedItem) {
    // dispose 阶段仍需上报 play_end，但 ConsumerState 的 ref 已不可访问。
    // 此时使用开始播放时保留在 item 上的权益类型；正常页面存活期仍读取最新
    // feed item，覆盖播放中完成解锁后的权益变化。
    if (_isDisposing || !mounted) {
      return startedItem.episode.viewingEntitlementType;
    }
    return _feedItemForId(startedItem.id)?.episode.viewingEntitlementType ??
        startedItem.episode.viewingEntitlementType;
  }

  String _subtitleLanguageForAnalytics(PlayerPlaybackState playback) {
    final hasSubtitleCapability =
        playback.availableSubtitles.isNotEmpty ||
        playback.availableEpisodeSources.isNotEmpty;
    if (!hasSubtitleCapability) {
      return 'none';
    }
    final language = playback.currentSubtitleLanguage?.trim();
    if (language == null || language.isEmpty) {
      return 'off';
    }
    for (final subtitle in playback.availableSubtitles) {
      if (subtitle.language == language) {
        final code = subtitle.languageCode.trim();
        return code.isEmpty ? language : code;
      }
    }
    for (final source in playback.availableEpisodeSources) {
      if (source.language == language) {
        final code = source.languageCode.trim();
        return code.isEmpty ? language : code;
      }
    }
    return language;
  }

  void _onAnalyticsPlayingChanged(bool isPlaying) {
    if (isPlaying) {
      _cancelAnalyticsPauseTimer();
      final playback = _providerContainer.read(
        playerPlaybackControllerProvider(_sessionKey),
      );
      if (_analyticsPlayingItemId == null &&
          playback.hasFirstFrame &&
          playback.currentItemId != null) {
        unawaited(_trackPlaybackStart(playback.currentItemId!));
      }
      return;
    }
    if (_analyticsPlayingItemId == null || _analyticsPauseTimer != null) {
      return;
    }
    _analyticsPauseTimer = Timer(const Duration(seconds: 30), () {
      _analyticsPauseTimer = null;
      if (!mounted) {
        return;
      }
      unawaited(_trackPlaybackEnd(reason: 'pause'));
    });
  }

  void _cancelAnalyticsPauseTimer() {
    _analyticsPauseTimer?.cancel();
    _analyticsPauseTimer = null;
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
    if (_isLeavingRoute || _isModalOpen) {
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
    final shouldResumePlayback = _resumePlaybackOnRouteReturn;
    _resumePlaybackOnRouteReturn = false;
    if (_previousLifecycleState != AppLifecycleState.resumed ||
        _isLeavingRoute) {
      return;
    }
    unawaited(_restoreAfterCoveredRoutePops(shouldResumePlayback));
  }

  Future<void> _restoreAfterCoveredRoutePops(bool shouldResumePlayback) async {
    if (widget.feedMode == PlayerFeedMode.forYou) {
      await _playbackController.resumeAfterCompetingPlayer();
    } else if (shouldResumePlayback) {
      await _resumePlaybackAfterLifecyclePause();
    } else {
      await _restorePlaybackSurfaceAfterVisibilityPause();
    }
    await _playPendingAdUnlockedEpisode();
  }

  Future<void> _playPendingAdUnlockedEpisode() async {
    final itemId = _pendingAdUnlockedItemId;
    if (itemId == null ||
        !mounted ||
        _isCoveredByAnotherRoute ||
        _previousLifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    final item = feedState.currentItem;
    if (item?.id != itemId) {
      return;
    }
    _pendingAdUnlockedItemId = null;
    await ref
        .read(playerRuntimeCoordinatorProvider(_sessionKey).notifier)
        .onViewportSettled(
          item: item!,
          index: feedState.currentIndex,
          playbackTrigger: 'ad_unlock',
        );
  }

  @override
  void initState() {
    super.initState();
    _providerContainer = ProviderScope.containerOf(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _pageController.addListener(_handlePageControllerTick);
    _sessionKey = _createSessionKey();
    _playbackController = ref.read(
      playerPlaybackControllerProvider(_sessionKey).notifier,
    );
    _analyticsService = ref.read(analyticsServiceProvider);
    _adUnlockEntryExposureTracker = AdUnlockEntryExposureTracker(
      analytics: _analyticsService,
    );
    _overlayOrchestrator = ref.read(
      playerOverlayOrchestratorProvider(_sessionKey).notifier,
    );
    _modalService = ref.read(appModalServiceProvider);
    if (widget.feedMode == PlayerFeedMode.singleDrama &&
        widget.dramaId != null &&
        widget.dramaId!.isNotEmpty) {
      // 与详情请求并行读取。第二次从未刷新的首页卡片进入时，优先使用这份本地
      // 最新位置，避免退回首页接口里的旧 watch_progress。
      _localResumeTargetFuture = ref
          .read(dramaPlaybackTargetRepositoryProvider)
          .getForDrama(widget.dramaId!);
    }
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

      // 收藏状态由随后加载的 `/api/home/detail.is_favorited` 同步到 like controller。
      // 不再在进入播放器时额外请求 `/api/user/short/follow/check`。

      await _loadFeedForTiming();
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
    // 底层 media_kit 的 pause/dispose 在少数机型上可能长期不回调。For You 的
    // 网络闸门会在 suspend 开始时立即关闭，因此普通页最多等待一小段时间，不能让
    // 路由进入永久卡在 loading；原暂停任务仍在后台继续完成。
    var timedOut = false;
    try {
      await ref
          .read(
            playerPlaybackControllerProvider(
              PlayerPlaybackSessionKeys.forYouTab,
            ).notifier,
          )
          .suspendForCompetingPlayer()
          .timeout(
            const Duration(milliseconds: 600),
            onTimeout: () {
              timedOut = true;
            },
          );
    } catch (error, stackTrace) {
      developer.log(
        'release competing For You decoder failed; continue player startup',
        error: error,
        stackTrace: stackTrace,
      );
      _playbackController.recordPlaybackTiming(
        'release competing forYou decoder failed',
        elapsed: stopwatch.elapsed,
        details: 'continueStartup=true error=$error',
      );
      return;
    }
    if (timedOut) {
      _playbackController.recordPlaybackTiming(
        'release competing forYou decoder timeout',
        elapsed: stopwatch.elapsed,
        details: 'timeoutMs=600 continueStartup=true',
      );
      return;
    }
    _playbackController.recordPlaybackTiming(
      'release competing forYou decoder end',
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  void dispose() {
    // 涓婃姤瑙傜湅閫€鍑轰簨浠?
    _isDisposing = true;
    _cancelAnalyticsPauseTimer();
    unawaited(_trackPlaybackEnd(reason: 'exit'));
    unawaited(_playbackController.reportWatchProgress(eventType: 4));
    WidgetsBinding.instance.removeObserver(this);
    playerRouteObserver.unsubscribe(this);
    _cancelExitRecommendationRequestIfPending();
    _modalService.dismissForSource(AppModalSource.player);
    _overlayOrchestrator.cancelPending();
    // widget tree 正在卸载时不能同步写 provider；这里只停止 surface 相关的计时
    // 和回调，实际 state 清理由后续 syncState=false 的 session dispose 完成。
    _playbackController.detachVideoSurfaceForTeardown(syncState: false);
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
    _pageController.removeListener(_handlePageControllerTick);
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
      } else if (previous != AppLifecycleState.resumed &&
          _isPlaybackViewVisible) {
        unawaited(_restorePlaybackSurfaceAfterVisibilityPause());
      }
      return;
    }
    // 璁板綍杩涘叆 inactive 鍓嶆槸鍚︽鍦ㄦ挱鏀撅紝鐢ㄤ簬鎭㈠鏃跺垽鏂槸鍚﹂渶瑕佽嚜鍔ㄦ挱鏀?
    if (state == AppLifecycleState.inactive) {
      final playback = _providerContainer.read(
        playerPlaybackControllerProvider(_sessionKey),
      );
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

  Future<void> _restorePlaybackSurfaceAfterVisibilityPause() async {
    await _playbackController.restoreSurfaceAfterVisibilityPause();
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
      await _loadFeedForTiming(forceRefresh: true, preserveVisibleItems: true);
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

  /// For You survives logout in the shell's indexed stack. Its feed is reset
  /// during session cleanup and is reloaded only when the user selects this tab.
  Future<void> _reloadForYouAfterSessionRecovery() async {
    if (_isReloadingForYouAfterSessionRecovery ||
        widget.feedMode != PlayerFeedMode.forYou) {
      return;
    }
    final feed = ref.read(playerFeedControllerProvider(_sessionKey));
    if (feed.config != null || feed.isLoading == false) {
      return;
    }
    _isReloadingForYouAfterSessionRecovery = true;
    try {
      final uiController = ref.read(
        playerUiControllerProvider(_sessionKey).notifier,
      );
      uiController.startSession('1');
      uiController.configureAutoImmersiveSession(enabled: false);
      await _loadFeedForTiming();
      if (!_isPlaybackViewVisible) {
        await _playbackController.pauseForVisibility();
      }
    } finally {
      _isReloadingForYouAfterSessionRecovery = false;
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

  Future<void> _handleForYouTabSelected() async {
    if (widget.feedMode != PlayerFeedMode.forYou || !_isPlaybackViewVisible) {
      return;
    }
    _reloadPendingForYouLanguageChangeOnReturn();
    // The tab selection is the explicit resume point after logout/login. This
    // opens the visibility gate before re-settling the replacement feed.
    await _playbackController.resumeAfterCompetingPlayer();
    await _reloadForYouAfterSessionRecovery();
    await _restoreRecoveredForYouPlaybackOnReturn();
  }

  /// Session recovery may finish while this indexed-stack page is hidden. The
  /// shell only resumes a player that was active when the user left For You;
  /// after logout there is intentionally no active source yet. Re-settle the
  /// recovered item on tab entry so the normal settled-only playback path can
  /// open it, or resume the source that was opened while hidden.
  Future<void> _restoreRecoveredForYouPlaybackOnReturn() async {
    if (widget.feedMode != PlayerFeedMode.forYou || !_isPlaybackViewVisible) {
      return;
    }
    final feed = ref.read(playerFeedControllerProvider(_sessionKey));
    final item = feed.currentItem;
    if (item == null) {
      return;
    }
    final playback = ref.read(playerPlaybackControllerProvider(_sessionKey));
    if (playback.currentSource != null) {
      await _playbackController.resumeAfterCompetingPlayer();
      return;
    }
    ref.invalidate(playerViewportControllerProvider(_sessionKey));
    _feedEngine.initializeViewport(index: feed.currentIndex, itemId: item.id);
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

  Future<void> _loadFeedForTiming({
    bool forceRefresh = false,
    bool preserveVisibleItems = false,
  }) async {
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
    await feedController.load(
      config,
      forceRefresh: forceRefresh,
      preserveVisibleItems: preserveVisibleItems,
    );
    stopwatch.stop();
    if (!mounted) {
      return;
    }
    var feedState = ref.read(feedProvider);
    if (widget.feedMode == PlayerFeedMode.singleDrama &&
        feedState.currentItem?.content.isDramaAvailable == false) {
      // 短剧整体下架时仍保留当前播放器页面，由既有 unavailable overlay 展示
      // 不可播放状态；这里只补一次明确的业务提示，避免误判为播放/网络失败。
      if (!_hasShownDramaTakenDownToast) {
        _hasShownDramaTakenDownToast = true;
        showAppCenterToast(context.l10n.myListDramaOffShelf);
      }
    }
    if (feedState.currentItem != null) {
      if (widget.forYouHandoff != null) {
        _applyInitialForYouHandoffProgress(feedState);
      } else {
        _startupRemoteWatchProgress =
            feedState.currentItem!.content.watchProgress;
        await _applyDetailWatchProgress(feedState);
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
    var targetItem = feedState.currentItem;
    if (targetItem == null) {
      return;
    }
    // For You 只交接当前集的真实结束位置；是否需要回退 8 秒必须等普通
    // 播放器拿到完整剧集列表和下一集权益后在这里统一决定。
    var duration = targetItem.episode.duration ?? handoff.duration;
    var normalizedPosition = handoff.position;
    var shouldRewindBeforeLockedNext = false;
    final currentIndex = feedState.currentIndex;
    final hasNextEpisode = currentIndex + 1 < feedState.items.length;
    if (_isAtOrNearEnd(handoff.position, duration) && hasNextEpisode) {
      final nextItem = feedState.items[currentIndex + 1];
      final nextIsPlayable =
          _feedEngine.accessPresentationFor(nextItem) ==
          PlayerAccessPresentationState.playable;
      if (nextIsPlayable) {
        ref
            .read(playerFeedControllerProvider(_sessionKey).notifier)
            .setCurrentIndex(currentIndex + 1);
        feedState = ref.read(playerFeedControllerProvider(_sessionKey));
        targetItem = feedState.currentItem!;
        duration = Duration.zero;
        normalizedPosition = Duration.zero;
      } else {
        shouldRewindBeforeLockedNext = true;
        normalizedPosition = _rewindPositionBeforeEnd(duration);
      }
    }
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

  Duration _rewindPositionBeforeEnd(Duration duration) {
    if (duration <= _lockedNextEpisodeRewind) {
      return Duration.zero;
    }
    return duration - _lockedNextEpisodeRewind;
  }

  bool _isAtOrNearEnd(Duration position, Duration duration) {
    return duration > Duration.zero &&
        position >= duration - _lockedNextEpisodeRewind;
  }

  Future<void> _applyDetailWatchProgress(PlayerFeedState feedState) async {
    final detailWatchProgress = _startupRemoteWatchProgress;
    final preferredCandidate = await _preferredInitialResumeCandidate(
      feedState.items,
    );
    final watchProgress = preferredCandidate?.progress ?? detailWatchProgress;
    if (watchProgress == null || feedState.items.isEmpty) {
      return;
    }
    _startupRemoteWatchProgress = null;

    _playbackController.recordPlaybackTiming(
      'initial resume target selected',
      details: [
        'source=${preferredCandidate?.source ?? 'detail'}',
        'episodeId=${watchProgress.episodeId}',
        'positionMs=${watchProgress.position.inMilliseconds}',
      ].join(' '),
    );

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
    if (!watchProgress.hasHistory) {
      _playbackController.recordPlaybackTiming(
        'detail watch progress empty',
        details: 'episodeNo=${watchProgress.episodeNo}',
      );
      return;
    }
    final remotePosition = watchProgress.position;
    final remoteDuration = watchProgress.duration;
    final canResume =
        remotePosition > Duration.zero &&
        remoteDuration > Duration.zero &&
        remotePosition < remoteDuration - const Duration(seconds: 2);
    var resumePosition = canResume ? remotePosition : Duration.zero;
    var resumeDuration = canResume ? remoteDuration : Duration.zero;
    if (remoteItemIndex + 1 < feedState.items.length) {
      final nextItem = feedState.items[remoteItemIndex + 1];
      final shouldRewindBeforeLockedNext =
          widget.feedMode == PlayerFeedMode.singleDrama &&
          remoteDuration > Duration.zero &&
          _feedEngine.accessPresentationFor(nextItem) !=
              PlayerAccessPresentationState.playable &&
          (!canResume || _isAtOrNearEnd(remotePosition, remoteDuration));
      if (shouldRewindBeforeLockedNext) {
        targetIndex = remoteItemIndex;
        resumePosition = remoteDuration > _lockedNextEpisodeRewind
            ? remoteDuration - _lockedNextEpisodeRewind
            : Duration.zero;
        resumeDuration = remoteDuration;
        _lockedNextRewoundCompletionItemId =
            feedState.items[remoteItemIndex].id;
      } else if (!canResume) {
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

  Future<_InitialResumeCandidate?> _preferredInitialResumeCandidate(
    List<PlayerFeedItem> items,
  ) async {
    if (widget.feedMode != PlayerFeedMode.singleDrama ||
        widget.dramaId == null ||
        items.isEmpty) {
      return null;
    }

    // 本地 SharedPreferences 异常时绝不能阻塞详情首播；它只用于让同一设备第二次
    // 进入使用更近的播放位置。读取已在 initState 与详情并行启动。
    DramaPlaybackTarget? localTarget;
    final localFuture = _localResumeTargetFuture;
    if (localFuture != null) {
      try {
        localTarget = await localFuture.timeout(
          const Duration(milliseconds: 80),
        );
      } on TimeoutException {
        _playbackController.recordPlaybackTiming(
          'local resume target read timeout',
          details: 'budgetMs=80',
        );
      } catch (_) {
        // 退回首页 hint / 详情 watch_progress。
      }
    }
    final localCandidate = _resumeCandidateForTarget(
      items,
      source: 'local',
      target: localTarget,
    );
    if (localCandidate != null) return localCandidate;

    final entry = ref.read(playerEntryPreloadCoordinatorProvider);
    final hint = entry.dramaId == widget.dramaId ? entry.resumeHint : null;
    if (hint == null || !hint.canResume) return null;
    return _resumeCandidateForValues(
      items,
      source: 'home',
      episodeId: hint.episodeId,
      position: hint.position,
      duration: hint.duration,
    );
  }

  _InitialResumeCandidate? _resumeCandidateForTarget(
    List<PlayerFeedItem> items, {
    required String source,
    required DramaPlaybackTarget? target,
  }) {
    if (target == null || !target.canResume) return null;
    return _resumeCandidateForValues(
      items,
      source: source,
      episodeId: target.episodeId,
      position: target.position,
      duration: target.duration,
    );
  }

  _InitialResumeCandidate? _resumeCandidateForValues(
    List<PlayerFeedItem> items, {
    required String source,
    required String episodeId,
    required Duration position,
    required Duration duration,
  }) {
    if (position <= Duration.zero || duration <= Duration.zero) return null;
    final item = items.where((candidate) {
      return candidate.episode.id == episodeId &&
          _feedEngine.accessPresentationFor(candidate) ==
              PlayerAccessPresentationState.playable;
    }).firstOrNull;
    if (item == null) return null;
    final progress = PlayerWatchProgress(
      episodeId: item.episode.id,
      episodeNo: item.episode.number,
      position: position,
      duration: duration,
      progressPercent: duration.inMilliseconds <= 0
          ? 0
          : (position.inMilliseconds * 100 ~/ duration.inMilliseconds).clamp(
              0,
              100,
            ),
    );
    return progress.hasHistory
        ? _InitialResumeCandidate(source: source, progress: progress)
        : null;
  }

  int _indexForRemoteWatchProgress(
    List<PlayerFeedItem> items,
    PlayerWatchProgress watchProgress,
  ) {
    return items.indexWhere((item) {
      return item.episode.id == watchProgress.episodeId ||
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
        unawaited(_handleForYouTabSelected());
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
        _prepareAdUnlockForSettledItem(settledItem);
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
      playerPlaybackControllerProvider(
        sessionKey,
      ).select((state) => state.isPlaying),
      (previous, next) {
        if (_shouldIgnoreRouteListener || previous == next) {
          return;
        }
        _onAnalyticsPlayingChanged(next);
      },
    );

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
        if (next.$1 == _analyticsPlayingItemId) {
          _analyticsPlaybackProgress = next.$3;
        }
        if (next.$1 == null ||
            next.$2 == null ||
            (next.$3 <= Duration.zero && !next.$5)) {
          return;
        }
        final latestFeed = _providerContainer.read(feedProvider);
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
        _providerContainer
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
        unawaited(_trackPlaybackStart(next.$1!));
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
        unawaited(_trackPlaybackEnd(reason: 'completed', itemId: next.$1!));
        // 涓婃姤瑙傜湅瀹屾垚浜嬩欢
        unawaited(
          playbackController.reportWatchProgress(eventType: 6),
        ); // 6: complete
        feedEngine.markEndedHandled(next.$1!);
        if (widget.feedMode == PlayerFeedMode.forYou) {
          final completedItem = _providerContainer
              .read(feedProvider)
              .currentItem;
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
      body: SafeArea(
        left: false,
        right: false,
        child: PopScope(
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
            // 在倒数第二条就取下一页，让用户真正滑到末条时网络请求通常已经完成。
            // 仍由 feed controller 的 isLoadingMore/hasMore 去重，短列表（仅一条）
            // 会在首条触发一次，保持首次数据不足时的兜底行为。
            if (widget.feedMode == PlayerFeedMode.forYou &&
                index >= items.length - 2) {
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
              onAdUnlockTap: () {
                unawaited(_openAdUnlock(item));
              },
              onAdUnlockEntryVisible: () {
                _reportAdUnlockEntryExposure(item);
              },
              onOpenMembership: () {
                unawaited(_showPendingUnlockActionSheet());
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
        if (widget.feedMode == PlayerFeedMode.forYou)
          PlayerForYouSearchButton(
            top: 8,
            onTap: () => unawaited(_openSearch()),
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

  void _handlePageControllerTick() {
    _syncActiveVideoPagePosition();
    _preloadForPredictedPageDuringScroll();
  }

  void _preloadForPredictedPageDuringScroll() {
    if (widget.feedMode != PlayerFeedMode.forYou ||
        !_pageController.hasClients) {
      return;
    }
    final page = _pageController.page;
    if (page == null || !page.isFinite) {
      return;
    }
    final feedState = ref.read(playerFeedControllerProvider(_sessionKey));
    final items = feedState.items;
    if (items.isEmpty) {
      return;
    }
    final viewport = ref.read(playerViewportControllerProvider(_sessionKey));
    if (viewport.scrollPhase == PlayerViewportScrollPhase.idle) {
      return;
    }
    final settledIndex = viewport.settledIndex.clamp(0, items.length - 1);
    final delta = page - settledIndex;
    if (delta.abs() < _predictivePreloadPageThreshold) {
      if (_lastPredictivePreloadIndex != null) {
        _lastPredictivePreloadIndex = null;
        unawaited(
          _feedEngine.cancelPredictedViewportPreload(
            reason: 'page_returned_before_settle',
          ),
        );
      }
      return;
    }
    final predictedIndex = (delta > 0 ? settledIndex + 1 : settledIndex - 1)
        .clamp(0, items.length - 1);
    if (predictedIndex == settledIndex ||
        predictedIndex == _lastPredictivePreloadIndex) {
      return;
    }
    if (_lastPredictivePreloadIndex != null) {
      unawaited(
        _feedEngine.cancelPredictedViewportPreload(reason: 'direction_changed'),
      );
    }
    _lastPredictivePreloadIndex = predictedIndex;
    unawaited(
      _feedEngine.preloadForPredictedViewport(
        items: items,
        currentIndex: settledIndex,
        predictedIndex: predictedIndex,
      ),
    );
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
    final isCurrentForYouItem =
        playbackState.currentItemId == item.id &&
        playbackState.currentSource != null;

    _isOpeningForYouPlayer = true;
    try {
      final effectiveDuration = playbackState.duration > Duration.zero
          ? playbackState.duration
          : item.episode.duration ?? Duration.zero;
      final shouldUseCurrentPlayback = isCurrentForYouItem;
      // 推荐接口返回的就是当前可播放剧集。即使用户在首帧 opening 阶段点击，
      // 也必须把这集带入详情播放器；不能退回硬编码的第 1 集，否则会错集、
      // 丢失可复用的 HLS 首段，并可能落到未解锁集。
      final targetEpisodeId = item.episode.id;
      final initialPosition = shouldUseCurrentPlayback
          ? playbackState.position
          // 播放完成回调时底层 source 可能已经释放；仍将“已完成”交给普通
          // 播放器判断下一集，而不是在 For You 里提前回退。
          : rewindFromEnd
          ? effectiveDuration
          : Duration.zero;
      final handoff = ForYouPlayerHandoff(
        id: '${item.id}:${DateTime.now().microsecondsSinceEpoch}',
        originItemId: item.id,
        dramaId: item.content.id,
        episodeId: targetEpisodeId,
        position: initialPosition,
        duration: (shouldUseCurrentPlayback || rewindFromEnd)
            ? effectiveDuration
            : Duration.zero,
      );
      ref
          .read(forYouPlaybackProgressControllerProvider.notifier)
          .save(
            ForYouPlaybackSnapshot(
              originItemId: item.id,
              dramaId: item.content.id,
              episode: item.episode,
              position: initialPosition,
              duration: (shouldUseCurrentPlayback || rewindFromEnd)
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
    final currentItem = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    if (currentItem == null) {
      _isModalOpen = false;
      _syncAutoImmersiveBlockers();
      return false;
    }
    final analytics = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(analyticsServiceProvider);
    final popupParameters = <String, Object?>{
      'popup_name': AnalyticsPopupNames.dramaExitRecommend,
      'drama_id': currentItem.content.id,
    };
    unawaited(
      analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.popupShow, popupParameters),
      ),
    );
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
          onCardTap: (recommendation) {
            _trackExitRecommendationClick(
              elementName: 'exit_recommend_drama_card',
              recommendation: recommendation,
              recommendations: recommendations,
            );
            Navigator.of(
              dialogContext,
            ).pop(_ExitRecommendationPlayResult(recommendation));
          },
          onPlay: (recommendation) {
            _trackExitRecommendationClick(
              elementName: 'exit_recommend_play_button',
              recommendation: recommendation,
              recommendations: recommendations,
            );
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

    unawaited(
      analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.popupClose, popupParameters),
      ),
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
    final userId = session.user?.userId.trim();
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
    preparePlayerEntryPreload(
      context,
      dramaId: '${recommendation.id}',
      episodeId: '1',
      trigger: 'exit_recommendation',
    );
    final location = RoutePaths.playerLocation(
      dramaId: '${recommendation.id}',
      episodeId: '1',
      trigger: 'exit_recommendation',
      userActionAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    context.pushReplacement(location);
  }

  void _trackExitRecommendationClick({
    required String elementName,
    required PopupExitRecommendation recommendation,
    required List<PopupExitRecommendation> recommendations,
  }) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': elementName,
              'drama_id': '${recommendation.id}',
              'position':
                  recommendations.indexWhere(
                    (item) => item.id == recommendation.id,
                  ) +
                  1,
            }),
          ),
    );
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
    PlayerRecommendation recommendation, {
    required int position,
  }) async {
    if (_isOpeningRecommendation) {
      return;
    }
    _isOpeningRecommendation = true;
    try {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .track(
              AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                'element_name': 'drama_card',
                'drama_id': recommendation.id,
                'position': position,
              }),
            ),
      );
      final shouldResumeWhenRecommendationReturns = ref
          .read(playerPlaybackControllerProvider(_sessionKey))
          .isPlaying;
      await _playbackController.pauseForVisibility();
      if (!mounted) {
        return;
      }

      preparePlayerEntryPreload(
        context,
        dramaId: recommendation.id,
        episodeId: '1',
        trigger: 'recommendation',
        resumeHint: playerEntryResumeHintFor(recommendation.watchProgress),
      );
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
    if (GoRouter.of(context).routerDelegate.currentConfiguration.uri.path ==
        RoutePaths.search) {
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
    // 重试沿用本次详情快照里的续播目标，不再补请求旧 progress 接口。播放失败后
    // 分片通常已进本地缓存，立即按原目标重开比再等待一轮网络更快。
    final detailProgress = item.content.watchProgress;
    if (widget.feedMode == PlayerFeedMode.singleDrama &&
        detailProgress != null &&
        detailProgress.hasHistory &&
        item.episode.id == detailProgress.episodeId) {
      _resumeProgress = PlaybackProgress(
        itemId: item.id,
        position: detailProgress.position,
        duration: detailProgress.duration,
        updatedAt: DateTime.now(),
      );
      _playbackController.setPendingResumeProgress(_resumeProgress);
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
    // Request early, but do not change the underlying paywall until the
    // original unlock sheet has been dismissed.
    final adUnlockStatus = _fetchAdUnlockStatus(item);
    var didUnlockWithCoins = false;
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    try {
      await _unlockModalCoordinator.presentSheetIntent(
        context,
        item,
        intent,
        launchedByAutoSheet: launchedByAutoSheet,
      );
      // 金币解锁成功后当前集已恢复播放；不能再使用打开金币框前预取到的
      // 广告资格弹出二次解锁确认框。
      didUnlockWithCoins =
          intent == PlayerOverlaySheetIntent.coinUnlock &&
          ref
                  .read(playerRechargeUnlockControllerProvider(_sessionKey))
                  .status ==
              PlayerRechargeUnlockStatus.success;
    } finally {
      if (mounted) {
        _isModalOpen = false;
        _activeCoinSheetItemId = null;
        _activeRechargeSheetItemId = null;
        _restoreUnlockPaywallAfterModalIfNeeded(item);
        if (!didUnlockWithCoins) {
          unawaited(
            _applyAdUnlockActionAfterOriginalSheet(item, adUnlockStatus),
          );
        }
        _syncAutoImmersiveBlockers();
      }
    }
  }

  Future<AdUnlockStatus?> _fetchAdUnlockStatus(PlayerFeedItem item) async {
    return _preloadAdUnlockStatus(item);
  }

  String _adUnlockCacheKey(PlayerFeedItem item) =>
      '${item.content.id}:${item.episode.id}';

  bool _isAdUnlockCandidate(PlayerFeedItem item) {
    return int.tryParse(item.content.id) != null &&
        item.episode.isLocked &&
        _isSequentialUnlockEligible(item);
  }

  bool _isAdUnlockTemporarilyUnavailable(PlayerFeedItem item) {
    final unavailableUntil = _adUnlockUnavailableUntil[_adUnlockCacheKey(item)];
    return unavailableUntil != null &&
        DateTime.now().isBefore(unavailableUntil);
  }

  Future<AdUnlockStatus?> _preloadAdUnlockStatus(PlayerFeedItem item) {
    if (!_isAdUnlockCandidate(item) ||
        _isAdUnlockTemporarilyUnavailable(item)) {
      return Future<AdUnlockStatus?>.value(null);
    }
    final key = _adUnlockCacheKey(item);
    final now = DateTime.now();
    final cached = _adUnlockStatusCache[key];
    if (cached != null &&
        now.difference(cached.fetchedAt) < _adUnlockStatusCacheTtl) {
      return Future<AdUnlockStatus?>.value(cached.status);
    }
    final inFlight = _adUnlockStatusInFlight[key];
    if (inFlight != null) return inFlight;

    final dramaId = int.tryParse(item.content.id);
    if (dramaId == null) return Future<AdUnlockStatus?>.value(null);
    final request = () async {
      try {
        final status = await ref
            .read(adUnlockRepositoryProvider)
            .fetchStatus(dramaId: dramaId, episodeNo: item.episode.number);
        _adUnlockStatusCache[key] = _AdUnlockStatusCacheEntry(
          status: status,
          fetchedAt: DateTime.now(),
        );
        return status;
      } catch (_) {
        return null;
      } finally {
        _adUnlockStatusInFlight.remove(key);
      }
    }();
    _adUnlockStatusInFlight[key] = request;
    return request;
  }

  Future<bool> _preloadAdMaterial({bool retryIfUnavailable = false}) async {
    if (_isAdMaterialUnavailable && !retryIfUnavailable) {
      return false;
    }
    try {
      await ref.read(adMaterialPreloaderProvider).ensureCachedMaterial();
      _isAdMaterialUnavailable = false;
      _adMaterialUnavailableMessage = null;
      return true;
    } on ApiException catch (error) {
      if (error.businessCode == 2501) {
        _isAdMaterialUnavailable = true;
        _adMaterialUnavailableMessage = error.message;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _prepareAdUnlockForSettledItem(PlayerFeedItem item) {
    if (!ref.read(useRemotePlayerApiProvider)) return;
    // 素材和剧集资格彼此独立：素材可在任何播放页后台预热，资格只预取当前
    // 顺序可解锁的锁定集，避免为普通集额外请求状态接口。
    unawaited(_preloadAdMaterial());
    if (_isAdUnlockCandidate(item)) {
      unawaited(_preloadAdUnlockStatus(item));
    }
  }

  bool _canPresentAdUnlockFor(PlayerFeedItem item) {
    final current = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    return mounted &&
        !_isDisposing &&
        !_isLeavingRoute &&
        !_isCoveredByAnotherRoute &&
        !_isModalOpen &&
        !_isPageScrolling &&
        _activeCoinSheetItemId == null &&
        _activeRechargeSheetItemId == null &&
        current?.id == item.id &&
        current != null &&
        current.episode.id == item.episode.id &&
        current.episode.isLocked &&
        _isSequentialUnlockEligible(current) &&
        !_isAdUnlockTemporarilyUnavailable(current);
  }

  void _markAdUnlockUnavailable(PlayerFeedItem item) {
    final key = _adUnlockCacheKey(item);
    _adUnlockUnavailableUntil[key] = DateTime.now().add(
      _adUnlockStatusCacheTtl,
    );
    _adUnlockStatusCache.remove(key);
    ref
        .read(playerFeedControllerProvider(_sessionKey).notifier)
        .updateItemEpisode(
          itemId: item.id,
          episode: item.episode.copyWith(
            adUnlock: const PlayerAdUnlockOffer(
              isAvailable: false,
              watchedToday: 0,
              dailyLimit: 0,
              closeAfter: Duration.zero,
            ),
          ),
        );
  }

  Future<void> _applyAdUnlockActionAfterOriginalSheet(
    PlayerFeedItem item,
    Future<AdUnlockStatus?> statusFuture,
  ) async {
    final status = await statusFuture;
    if (status == null || !_canPresentAdUnlockFor(item)) return;
    final latest = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    if (latest?.id != item.id ||
        !latest!.episode.isLocked ||
        !_isSequentialUnlockEligible(latest) ||
        !status.canShowPaywallAction(
          latest.episode.unlockType == EpisodeUnlockType.membership
              ? AdUnlockDramaKind.member
              : AdUnlockDramaKind.normal,
        )) {
      return;
    }
    final kind = latest.episode.unlockType == EpisodeUnlockType.membership
        ? AdUnlockDramaKind.member
        : AdUnlockDramaKind.normal;
    // 状态接口已确认当前集可展示广告解锁时，即使先前后台素材预热返回过
    // 2501，也应重新尝试一次，不能用素材失败覆盖最新资格状态。
    final materialPrepared = await _preloadAdMaterial(retryIfUnavailable: true);
    if (!materialPrepared || !_canPresentAdUnlockFor(item)) return;
    final materialPreloader = ref.read(adMaterialPreloaderProvider);
    final material = materialPreloader.cachedMaterial;
    if (material == null) return;
    final updatedItem = ref
        .read(playerFeedControllerProvider(_sessionKey).notifier)
        .updateItemEpisode(
          itemId: item.id,
          episode: latest.episode.copyWith(
            adUnlock: PlayerAdUnlockOffer(
              isAvailable: true,
              watchedToday: status.usedCount(kind),
              dailyLimit: status.dailyLimit(kind),
              closeAfter: const Duration(seconds: 0),
            ),
          ),
        );
    if (!mounted || updatedItem == null) return;
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    final bool shouldWatchAd;
    try {
      shouldWatchAd = await showAdUnlockPromptDialog(
        context,
        coverUrl: latest.content.coverUrl,
        watchedToday: status.usedCount(kind),
        dailyLimit: status.dailyLimit(kind),
        analytics: ref.read(analyticsServiceProvider),
        dramaId: latest.content.id,
        episodeId: latest.episode.id,
        dramaAccessType: _adUnlockDramaAccessType(latest),
        adMaterialId: material.id.toString(),
      );
    } finally {
      _isModalOpen = false;
      if (mounted) {
        _syncAutoImmersiveBlockers();
      }
    }
    if (!mounted || !shouldWatchAd) return;
    await _openAdUnlock(updatedItem, actionAlreadyTracked: true);
  }

  bool _isSequentialUnlockEligible(PlayerFeedItem item) {
    final entitlement = ref.read(entitlementControllerProvider);
    return item.content.isSequentialUnlockEligible(
      item.episode,
      isEpisodeUnlocked: entitlement.isEpisodeUnlocked,
    );
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
    final isEpisodeSelector = initialTab == PlayerDetailTab.episodes;
    final analytics = ref.read(analyticsServiceProvider);
    final popupParameters = <String, Object?>{
      'popup_name': AnalyticsPopupNames.episodeSelector,
      'drama_id': content.id,
    };
    if (isEpisodeSelector) {
      unawaited(
        analytics.track(
          AnalyticsEvent(AnalyticsDefinitions.popupShow, popupParameters),
        ),
      );
    }

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
              onRecommendationSelected: (recommendation, position) {
                unawaited(
                  _openRecommendationFromDetailSheet(
                    recommendation,
                    position: position,
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      if (isEpisodeSelector) {
        unawaited(
          analytics.track(
            AnalyticsEvent(AnalyticsDefinitions.popupClose, popupParameters),
          ),
        );
      }
      _isModalOpen = false;
      if (mounted) {
        _syncAutoImmersiveBlockers();
      }
    });
  }

  Future<void> _showShareSheet(String dramaId, String dramaTitle) {
    _isModalOpen = true;
    _syncAutoImmersiveBlockers();
    final analytics = ref.read(analyticsServiceProvider);
    final popupParameters = <String, Object?>{
      'popup_name': AnalyticsPopupNames.share,
      'drama_id': dramaId,
    };
    unawaited(
      analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.elementClick, {
          'element_name': 'share_entry',
          'drama_id': dramaId,
        }),
      ),
    );
    unawaited(
      analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.popupShow, popupParameters),
      ),
    );
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isDismissible: true,
      enableDrag: true,
      builder: (context) => PlayerShareSheet(
        onFacebookTap: () {
          unawaited(_trackShareChannelClick(dramaId, 'facebook'));
          unawaited(_reportDramaShareAction(dramaId, 'facebook'));
          unawaited(_shareToFacebook(dramaId, dramaTitle));
        },
        onCopyLinkTap: () {
          unawaited(_trackShareChannelClick(dramaId, 'copy_link'));
          unawaited(_reportDramaShareAction(dramaId, 'copy_link'));
          unawaited(_copyShareLink(dramaId, dramaTitle));
        },
      ),
    ).whenComplete(() {
      unawaited(
        analytics.track(
          AnalyticsEvent(AnalyticsDefinitions.popupClose, popupParameters),
        ),
      );
      _isModalOpen = false;
      if (mounted) {
        _syncAutoImmersiveBlockers();
      }
    });
  }

  Future<void> _trackShareChannelClick(String dramaId, String shareMethod) =>
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'share_channel',
              'drama_id': dramaId,
              'share_method': shareMethod,
            }),
          );

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
    final shareUrl = _facebookShareUrl(dramaId);
    final shareMessage = _shareMessage(dramaTitle, shareUrl);
    final facebookShareUrl = Uri.https(
      'www.facebook.com',
      '/sharer/sharer.php',
      {'u': shareUrl.toString(), 'quote': shareMessage},
    );
    developer.log("facebook链接facebookShareUrl:${facebookShareUrl.toString()}");
    developer.log("facebook链接shareUrl:${shareUrl.toString()}");
    final opened = await ref
        .read(externalUrlLauncherProvider)
        .open(facebookShareUrl.toString());
    if (!opened) {
      debugPrint(
        '[PlayerShare] Failed to open Facebook share: $facebookShareUrl',
      );
    }
  }

  Uri _shareUrl(String dramaId, {required String shareMethod}) {
    final languageCode = apiLangFromLocale(
      ref.read(appLocaleControllerProvider),
    );
    final entitlement = ref.read(entitlementControllerProvider);
    final userInfo = ref.read(userInfoStoreProvider);
    final channel = ref.read(channelConfigServiceProvider).cachedConfig;
    return AppConfig.current.shareUrl(
      dramaId: dramaId,
      languageCode: languageCode,
      userId: entitlement.userId ?? userInfo.userId ?? '',
      channelId: channel?.channelFlag ?? '',
      merchantId: channel?.merchantId ?? '',
      shareMethod: shareMethod,
    );
  }

  Uri _facebookShareUrl(String dramaId) {
    final languageCode = apiLangFromLocale(
      ref.read(appLocaleControllerProvider),
    );
    final entitlement = ref.read(entitlementControllerProvider);
    final userInfo = ref.read(userInfoStoreProvider);
    final channel = ref.read(channelConfigServiceProvider).cachedConfig;
    return AppConfig.current.facebookShareUrl(
      dramaId: dramaId,
      languageCode: languageCode,
      userId: entitlement.userId ?? userInfo.userId ?? '',
      channelId: channel?.channelFlag ?? '',
      merchantId: channel?.merchantId ?? '',
    );
  }

  String _shareMessage(String dramaTitle, Uri shareUrl) {
    return context.l10n.shareMessage(
      dramaTitle: dramaTitle,
      shareUrl: shareUrl.toString(),
    );
  }

  Future<void> _copyShareLink(String dramaId, String dramaTitle) async {
    final shareMessage = _shareMessage(
      dramaTitle,
      _shareUrl(dramaId, shareMethod: 'copy_link'),
    );
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
    final now = DateTime.now();
    if (_isModalOpen ||
        _isOpeningUnlockActionSheet ||
        (_lastUnlockTapAt != null &&
            now.difference(_lastUnlockTapAt!) < _unlockTapDebounce)) {
      return;
    }
    _lastUnlockTapAt = now;
    _isOpeningUnlockActionSheet = true;
    try {
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
    } finally {
      _isOpeningUnlockActionSheet = false;
    }
  }

  Future<void> _openAdUnlock(
    PlayerFeedItem item, {
    bool actionAlreadyTracked = false,
  }) async {
    final offer = item.episode.adUnlock;
    if (offer == null || !offer.isAvailable || _isModalOpen) return;
    if (offer.dailyLimit > 0 && offer.watchedToday >= offer.dailyLimit) {
      showAppCenterToast(
        item.episode.unlockType == EpisodeUnlockType.membership
            ? context.l10n.playerAdLimitVip
            : context.l10n.playerAdLimitRegular,
      );
      return;
    }
    final dramaId = int.tryParse(item.content.id);
    if (dramaId == null) return;
    // 用户主动点击时也允许重试素材，后台配置可能已在本次会话内恢复。
    final materialPrepared = await _preloadAdMaterial(retryIfUnavailable: true);
    if (!mounted || !_canPresentAdUnlockFor(item)) return;
    if (!materialPrepared) {
      if (_isAdMaterialUnavailable) {
        _markAdUnlockUnavailable(item);
        showAppCenterToast(_adMaterialUnavailableMessage ?? '广告解锁未开启');
        return;
      }
      showAppCenterToast('网络错误，请稍后重试');
      return;
    }
    final materialPreloader = ref.read(adMaterialPreloaderProvider);
    final material = materialPreloader.cachedMaterial;
    if (material == null) {
      showAppCenterToast('网络错误，请稍后重试');
      return;
    }
    if (!actionAlreadyTracked) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .track(
              AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                'element_name': 'ad_unlock_button',
                ...adUnlockPopupAnalyticsParameters(
                  dramaId: item.content.id,
                  episodeId: item.episode.id,
                  dramaAccessType: _adUnlockDramaAccessType(item),
                  adMaterialId: material.id.toString(),
                ),
              }),
            ),
      );
    }
    final sessionController = AdUnlockSessionController(
      repository: ref.read(adUnlockRepositoryProvider),
    );
    await sessionController.createSession(
      dramaId: dramaId,
      episodeNo: item.episode.number,
      materialId: material.id,
    );
    if (!mounted || !_canPresentAdUnlockFor(item)) return;
    if (sessionController.session == null) {
      final error = sessionController.error;
      if (error is ApiException && error.businessCode == 2501) {
        _markAdUnlockUnavailable(item);
        showAppCenterToast(error.message);
        return;
      }
      showAppCenterToast(context.l10n.networkError);
      return;
    }
    final session = materialPreloader.applyCachedMaterial(
      sessionController.session!,
    );
    materialPreloader.consumeMaterial(session);
    final result = await Navigator.of(context).push<AdUnlockRouteResult>(
      MaterialPageRoute(
        builder: (_) => AdUnlockPage(
          session: session,
          dramaId: item.content.id,
          episodeId: item.episode.id,
          onUnlockConfirmed: () => _refreshAdUnlockedEpisode(item),
        ),
      ),
    );
    if (!mounted || result is! AdUnlockRouteResult) return;
    await result.refreshFuture;
    await _playPendingAdUnlockedEpisode();
  }

  String _adUnlockDramaAccessType(PlayerFeedItem item) =>
      item.episode.unlockType == EpisodeUnlockType.membership
      ? 'vip'
      : 'normal';

  void _reportAdUnlockEntryExposure(PlayerFeedItem item) {
    final current = ref
        .read(playerFeedControllerProvider(_sessionKey))
        .currentItem;
    final material = ref.read(adMaterialPreloaderProvider).cachedMaterial;
    if (current?.id != item.id ||
        !item.episode.isLocked ||
        item.episode.adUnlock?.isAvailable != true ||
        material == null) {
      return;
    }
    unawaited(
      _adUnlockEntryExposureTracker.reportIfVisible(
        dramaId: item.content.id,
        episodeId: item.episode.id,
        dramaAccessType: item.episode.unlockType == EpisodeUnlockType.membership
            ? 'vip'
            : 'normal',
        adMaterialId: material.id.toString(),
      ),
    );
  }

  Future<bool> _refreshAdUnlockedEpisode(PlayerFeedItem item) async {
    final dramaId = int.tryParse(item.content.id);
    if (dramaId == null) return false;
    try {
      final detail = await ref
          .read(playerRemoteDataSourceProvider)
          .fetchDramaDetail(dramaId: dramaId);
      if (!mounted) return false;
      final content = const PlayerContentMapper().mapContent(detail);
      PlayerEpisode? refreshedEpisode;
      for (final episode in content.episodes) {
        if (episode.id == item.episode.id) {
          refreshedEpisode = episode;
          break;
        }
      }
      if (refreshedEpisode == null) return false;
      final updatedItem = ref
          .read(playerFeedControllerProvider(_sessionKey).notifier)
          .updateItemEpisode(itemId: item.id, episode: refreshedEpisode);
      if (updatedItem == null) return false;
      ref
          .read(entitlementControllerProvider.notifier)
          .updateAfterAdUnlock(episodeId: item.episode.id);
      // 广告确认与路由关闭存在竞态：详情可能在关闭前或关闭后才返回。
      // 记录待播放项，并在两种时机都尝试消费，避免只刷新 UI 却遗漏播放指令。
      _pendingAdUnlockedItemId = updatedItem.id;
      if (!_isCoveredByAnotherRoute) {
        unawaited(_playPendingAdUnlockedEpisode());
      }
      return true;
    } catch (_) {
      return false;
    }
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
