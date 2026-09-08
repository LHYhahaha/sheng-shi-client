import 'dart:async';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bootstrap/feature_session_cleanup.dart';
import '../bootstrap/i18n_bootstrap.dart';
import '../core/active/app_active_reporter.dart';
import '../core/adjust/adjust_device_identifier_reporter_provider.dart';
import '../core/adjust/adjust_event_reporter_provider.dart';
import '../core/adjust/adjust_service.dart';
import '../core/account/account_ban_controller.dart';
import '../core/account/account_banned_overlay.dart';
import '../core/analytics/analytics_definition.dart';
import '../core/analytics/analytics_entry_source.dart';
import '../core/analytics/analytics_event.dart';
import '../core/analytics/analytics_lifecycle_tracker.dart';
import '../core/analytics/analytics_page_context.dart';
import '../core/analytics/analytics_page_tracker.dart';
import '../core/analytics/analytics_provider.dart';
import '../core/i18n/i18n.dart';
import '../core/locale/runtime_supported_locales_provider.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/modal/app_modal_host.dart';
import '../core/network/api_client_provider.dart';
import '../core/network/api_exception.dart';
import '../core/notification/fcm_notification.dart';
import '../core/notification/fcm_notification_service.dart';
import '../core/notification/startup_notification_permission_requester.dart';
import '../core/notification/startup_notification_permission_reporter.dart';
import '../core/auth/auth_token_store.dart';
import '../core/runtime/install_id_provider.dart';
import '../core/runtime/startup_loading_timing.dart';
import '../core/toast/app_center_toast.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/bottom_tab_config/application/bottom_tab_config_controller.dart';
import '../features/entitlement/application/entitlement_controller.dart';
import '../features/gift/application/gift_deep_link.dart';
import '../features/gift/data/gift_remote_data_source_provider.dart';
import '../features/gift/domain/gift_claim_data.dart';
import '../features/pay/application/payment_loading_controller.dart';
import '../features/player/application/player_entry_preload_coordinator.dart';
import '../features/player/application/share_drama_reward_coordinator.dart';
import '../features/popup/application/popup_entry_controller.dart';
import '../features/popup/application/popup_analytics.dart';
import '../features/popup/domain/popup.dart';
import '../features/popup/presentation/widgets/popup_entry_overlay.dart';
import '../l10n/app_localizations.dart';
import '../shared/url/external_url_launcher.dart';
import '../shared/widgets/app_blocking_loading_overlay.dart';
import 'presentation/widgets/startup_splash_gate.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';
import 'shell/app_shell.dart';
import 'shell/app_shell_chrome.dart';
import 'theme/app_theme.dart';

class DramaClientApp extends ConsumerStatefulWidget {
  const DramaClientApp({
    this.fcmNotificationService,
    this.fcmNotificationServiceFuture,
    super.key,
  });

  final FcmNotificationService? fcmNotificationService;
  final Future<FcmNotificationService?>? fcmNotificationServiceFuture;

  @override
  ConsumerState<DramaClientApp> createState() => _DramaClientAppState();
}

class _DramaClientAppState extends ConsumerState<DramaClientApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _appLinkSubscription;
  StreamSubscription<FcmNotification>? _fcmNotificationTapSubscription;
  StreamSubscription<String>? _fcmTokenRefreshSubscription;
  ProviderSubscription<AuthTokenSnapshot>? _authTokenSubscription;
  FcmNotificationService? _fcmNotificationService;
  GoRouter? _router;
  bool _popupFlowCancellationScheduled = false;
  final Completer<void> _startupAuthenticationReady = Completer<void>();
  final _notificationPermissionRequester =
      StartupNotificationPermissionRequester();
  int _externalPlayerOpenGeneration = 0;
  bool _isWaitingForExternalPlayerAuthentication = false;

  // This State is above MaterialApp, so its context has no Localizations.
  AppLocalizations get _appLocalizations =>
      AppLocalizations(ref.read(appLocaleControllerProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final router = ref.read(appRouterProvider);
    _router = router;
    router.routerDelegate.addListener(_handleRootRouteChanged);
    _setPreferredOrientations();
    _listenForAppLinks();
    _authTokenSubscription = ref.listenManual<AuthTokenSnapshot>(
      authTokenStoreProvider,
      (previous, next) {
        // 首启认证由 _reportAppLaunchAfterFcmReady 统一处理；这里只补偿启动后
        // 用户登录或游客 session 恢复，避免 FCM token 因初始无 session 而滞留。
        if (_startupAuthenticationReady.isCompleted &&
            !(previous?.hasAccessToken ?? false) &&
            next.hasAccessToken) {
          unawaited(_reportAppLaunchAfterFcmReady());
        }
      },
    );
    _fcmNotificationService = widget.fcmNotificationService;
    _listenForFcmNotificationTaps();
    _listenForFcmTokenRefresh();
    unawaited(_listenForFcmNotificationTapsWhenReady());
    unawaited(_reportAppLaunchAfterFcmReady());
    // 与 DeviceId、认证并行读取渠道配置。ApiClient 仍会等待同一份配置完成后再
    // 发送请求；原生未提供配置时按约定使用空渠道头继续。
    unawaited(ref.read(channelConfigInitializerProvider.future));
    unawaited(_initializeAdjust());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_requestStartupNotificationPermission());
      }
    });
    Future.microtask(_bootstrapSessionAndI18n);
  }

  Future<void> _requestStartupNotificationPermission() async {
    await _notificationPermissionRequester.requestIfNeeded();
    if (!mounted) return;
    await ref
        .read(startupNotificationPermissionReporterProvider)
        .syncForAccount(ref.read(userInfoStoreProvider).showId);
  }

  Future<void> _initializeAdjust() async {
    final stopwatch = Stopwatch()..start();
    try {
      // 先确保内部 Device-Id 已生成，匿名 Adjust 上报即可携带稳定请求头。
      await ref.read(installIdProvider.future);
      debugPrint(
        '[StartupSdk] Adjust device-id ready '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      if (!mounted) return;
      AdjustService(
        deviceIdentifierReporter: ref.read(
          adjustDeviceIdentifierReporterProvider,
        ),
        onDeferredDeeplink: _handleAdjustDeferredDeeplink,
      ).initialize();
      // 曾在 SDK 会话确认前触发的事件会保留在本地；本次启动也要注册
      // session-success 后的补发，不能只依赖重新进入播放器。
      unawaited(ref.read(adjustEventReporterProvider).recoverPendingEvents());
      debugPrint(
        '[StartupSdk] Adjust init request end '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[StartupSdk] Adjust init failed '
        'elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      debugPrint('[Adjust] Startup initialization skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleAdjustDeferredDeeplink(Uri deeplink) {
    // Adjust 的首启回调可能早于首帧完成；延后到下一帧，确保 GoRouter 可用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_handleAppLink(deeplink));
      }
    });
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    _fcmNotificationTapSubscription?.cancel();
    _fcmTokenRefreshSubscription?.cancel();
    _authTokenSubscription?.close();
    _router?.routerDelegate.removeListener(_handleRootRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleRootRouteChanged() {
    final path = _router?.routerDelegate.currentConfiguration.uri.path;
    // 首页和推荐页的入口弹框由 AppShell 按 Tab 管理。任何 Shell 外页面都不能
    // 保留根 Overlay；这也覆盖了页面内 push，而不仅是通知和 Deep Link。
    if (path != RoutePaths.home && path != RoutePaths.forYou) {
      _schedulePopupFlowCancellationForRouteExit();
    }
  }

  void _schedulePopupFlowCancellationForRouteExit() {
    if (_popupFlowCancellationScheduled) return;
    _popupFlowCancellationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _popupFlowCancellationScheduled = false;
      if (!mounted) return;

      // GoRouter 会在构建阶段通知路由变化；延后到本帧结束再更新 Riverpod，
      // 避免在 widget tree building 时修改 provider。再次读取路径，防止同一帧
      // 内已经返回首页/推荐页时误取消其入口弹框。
      final path = _router?.routerDelegate.currentConfiguration.uri.path;
      if (path != RoutePaths.home && path != RoutePaths.forYou) {
        _cancelAllPopupFlowsForRouteExit();
      }
    });
  }

  void _listenForAppLinks() {
    _appLinkSubscription = AppLinks().uriLinkStream.listen(
      _handleAppLink,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[AppLink] Failed to receive link: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _handleAppLink(Uri uri) async {
    log("深链接数据：${uri.toString()}");
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    final isPlayerScheme = uri.scheme == 'novashort' && uri.host == 'player';
    final isAdjustLink =
        uri.scheme == 'https' && uri.host == 'juan365drama.go.link';
    if (!isPlayerScheme && !isAdjustLink) {
      debugPrint('[AppLink] Ignored unsupported link: $uri');
      return;
    }

    final gift = GiftDeepLink.tryParse(uri);
    if (gift != null) {
      await _handleGiftAppLink(gift);
      return;
    }

    final dramaId = uri.queryParameters['drama_id']?.trim();
    if (dramaId == null || dramaId.isEmpty) {
      debugPrint('[AppLink] Missing drama_id: $uri');
      return;
    }

    // App Link 可以在首页弹框尚未预加载完成时直接把 App 带到播放器。根 Overlay
    // 不随路由销毁，必须先取消所有入口位，防止请求回包后覆盖播放器页面。
    _cancelAllPopupFlowsForRouteExit();

    // 当前仅有短剧分享通过 player 深链接回流 App。埋点以成功解析为准，不把
    // 无效 scheme、host 或 drama_id 缺失的外部 Intent 计为分享来源打开。
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            const AnalyticsEvent(AnalyticsDefinitions.shareAppOpen, {
              'landing_type': 'normal_share',
            }),
          ),
    );

    // 当前 App Link 仅支持分享短剧播放器链接；分享没有稳定配置 ID，按约定留空。
    _prepareEntrySource(type: 'share_deeplink');

    // 与通知再次打开已展示的目标页一致：GoRouter 对相同 location 不一定产生新的
    // Navigator 回调，因此需要主动结束当前页面会话并强制生成目标 page_view，确保
    // share_deeplink 只附着到这一次实际被重新打开的播放器页面。
    if (ref.read(analyticsPageContextProvider).currentPage ==
        AnalyticsPageNames.dramaPlay) {
      await ref
          .read(analyticsPageTrackerProvider)
          .replace(AnalyticsPageNames.dramaPlay, forcePageView: true);
      if (!mounted) {
        return;
      }
    }

    await _openExternalPlayerWhenAuthenticationReady(
      dramaId: dramaId,
      episodeId: '1',
      trigger: 'app_link',
    );
  }

  Future<void> _handleGiftAppLink(GiftDeepLink gift) async {
    // 领取接口要求有效 token。冷启动或 session 恢复期间先等待认证完成，不能因
    // 深链接只到达一次而错过后续领取。
    if (!await _waitForExternalPlayerAuthentication()) {
      return;
    }
    if (!mounted) return;

    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.shareAppOpen, {
              'landing_type': gift.type == GiftDeepLinkType.drama
                  ? 'drama_gift'
                  : 'temp_vip_gift',
            }),
          ),
    );

    if (gift.type == GiftDeepLinkType.drama && gift.dramaId != null) {
      _cancelAllPopupFlowsForRouteExit();
      _prepareEntrySource(type: 'share_deeplink');
      await _openExternalPlayerWhenAuthenticationReady(
        dramaId: gift.dramaId!,
        episodeId: '1',
        trigger: 'drama_gift_deeplink',
        giftShareCode: gift.shareCode,
        deferPlayerPreload: true,
      );
      return;
    }

    final GiftClaimData claim;
    try {
      claim = await ref
          .read(giftRemoteDataSourceProvider)
          .claimGift(shareCode: gift.shareCode);
    } on ApiException catch (error) {
      if (mounted) {
        showAppCenterToast(
          _appLocalizations.giftClaimFailureForReason(
            error.businessCode == 3206 ? 8 : -1,
          ),
        );
      }
      debugPrint(
        '[GiftDeepLink] Gift claim failed: '
        'code=${error.code.name}, businessCode=${error.businessCode}',
      );
      return;
    } catch (error, stackTrace) {
      debugPrint('[GiftDeepLink] Gift claim failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
    if (!mounted) return;

    if (!claim.isSuccess) {
      showAppCenterToast(
        _appLocalizations.giftClaimFailureForReason(claim.reasonCode),
      );
      return;
    }

    if (claim.isTemporaryVip) {
      showAppCenterToast(
        _appLocalizations.memberGiftClaimed(days: claim.benefitDays),
      );
      await ref
          .read(entitlementControllerProvider.notifier)
          .refreshFromServer();
      return;
    }

    showAppCenterToast(
      _appLocalizations.giftClaimSuccess(benefitDays: claim.benefitDays),
    );

    if (!claim.isDrama || claim.dramaId.isEmpty || claim.dramaId == '0') return;

    await _openClaimedGiftDrama(claim.dramaId);
  }

  Future<void> _openClaimedGiftDrama(String dramaId) async {
    _cancelAllPopupFlowsForRouteExit();
    _prepareEntrySource(type: 'share_deeplink');
    await _openExternalPlayerWhenAuthenticationReady(
      dramaId: dramaId,
      episodeId: '1',
      trigger: 'drama_gift_deeplink',
    );
  }

  /// 冷启动外部入口可能在设备登录完成前到达。播放器详情和 source 都要求可用
  /// token，不能让首次请求把“鉴权尚未就绪”写成播放失败态。
  Future<bool> _waitForExternalPlayerAuthentication() async {
    final requestGeneration = ++_externalPlayerOpenGeneration;
    if (ref.read(authTokenStoreProvider).hasAccessToken) {
      if (mounted && _isWaitingForExternalPlayerAuthentication) {
        setState(() => _isWaitingForExternalPlayerAuthentication = false);
      }
      return true;
    }
    if (mounted) {
      setState(() => _isWaitingForExternalPlayerAuthentication = true);
    }
    await _startupAuthenticationReady.future;
    if (!mounted || requestGeneration != _externalPlayerOpenGeneration) {
      return false;
    }
    final hasAccessToken = ref.read(authTokenStoreProvider).hasAccessToken;
    if (!hasAccessToken) {
      debugPrint(
        '[ExternalPlayerEntry] Authentication completed without a token; '
        'player route was not opened.',
      );
    }
    if (mounted) {
      setState(() => _isWaitingForExternalPlayerAuthentication = false);
    }
    return hasAccessToken;
  }

  Future<void> _openExternalPlayerWhenAuthenticationReady({
    required String dramaId,
    required String episodeId,
    required String trigger,
    String? giftShareCode,
    bool deferPlayerPreload = false,
  }) async {
    if (!await _waitForExternalPlayerAuthentication()) {
      return;
    }
    if (!mounted) return;
    if (!deferPlayerPreload) {
      preparePlayerEntryPreload(
        context,
        dramaId: dramaId,
        episodeId: episodeId,
        trigger: trigger,
      );
    }
    final location = RoutePaths.playerLocation(
      dramaId: dramaId,
      episodeId: episodeId,
      trigger: trigger,
      userActionAtMs: DateTime.now().millisecondsSinceEpoch,
      giftShareCode: giftShareCode,
    );
    debugPrint('[ExternalPlayerEntry] Opening drama $dramaId trigger=$trigger');
    ref.read(appRouterProvider).go(location);
  }

  void _listenForFcmNotificationTaps() {
    final service = _fcmNotificationService;
    if (service == null) return;
    _fcmNotificationTapSubscription = service.onNotificationTap.listen(
      _handleFcmNotificationTap,
    );
    final initialNotification = service.takeInitialNotificationTap();
    if (initialNotification != null) {
      Future.microtask(() => _handleFcmNotificationTap(initialNotification));
    }
  }

  void _listenForFcmTokenRefresh() {
    final service = _fcmNotificationService;
    if (service == null) return;
    _fcmTokenRefreshSubscription?.cancel();
    _fcmTokenRefreshSubscription = service.onTokenRefresh.listen((_) {
      unawaited(_reportAppLaunchAfterFcmReady());
    });
  }

  Future<void> _listenForFcmNotificationTapsWhenReady() async {
    final service = await widget.fcmNotificationServiceFuture;
    if (!mounted ||
        service == null ||
        identical(service, _fcmNotificationService)) {
      return;
    }
    _fcmNotificationService = service;
    _listenForFcmNotificationTaps();
    _listenForFcmTokenRefresh();
  }

  void _handleFcmNotificationTap(FcmNotification notification) {
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    final data = notification.data;
    // `dump_type` is the current push contract. Keep `type` as a fallback so
    // notifications sent by older server versions remain actionable.
    final type =
        data['dump_type']?.trim().toLowerCase() ??
        data['type']?.trim().toLowerCase();
    final dramaId = data['drama_id']?.trim();
    final episodeId = data['episode_id']?.trim();
    final openType = data['h5_open_type']?.trim() ?? data['open_type']?.trim();
    final router = ref.read(appRouterProvider);

    _trackPushNotificationOpen(
      notification: notification,
      targetType: switch (type) {
        'player' || 'drama' || 'drama_detail' || 'detail' => 'drama',
        'page' => 'page',
        'h5' || 'webview' || 'web' => 'h5',
        _ => null,
      },
      dramaId: dramaId,
    );

    if (type == 'player' && dramaId != null && dramaId.isNotEmpty) {
      _cancelPopupForCurrentRouteExit();
      _preparePushEntrySource(notification);
      unawaited(
        _openExternalPlayerWhenAuthenticationReady(
          dramaId: dramaId,
          episodeId: episodeId?.isNotEmpty == true ? episodeId! : '1',
          trigger: 'fcm_notification',
        ),
      );
      return;
    }

    // 当前客户端没有独立的短剧详情路由，详情通知进入该剧第一集的播放器。
    if ((type == 'drama' || type == 'drama_detail' || type == 'detail') &&
        dramaId != null &&
        dramaId.isNotEmpty) {
      _cancelPopupForCurrentRouteExit();
      _preparePushEntrySource(notification);
      unawaited(
        _openExternalPlayerWhenAuthenticationReady(
          dramaId: dramaId,
          episodeId: '1',
          trigger: 'fcm_notification_detail',
        ),
      );
      return;
    }

    if (type == 'page') {
      _cancelPopupForCurrentRouteExit();
      if (_isSupportedFcmPage(data['page'])) {
        _preparePushEntrySource(notification);
      }
      _openFcmPage(router, data['page']);
      return;
    }

    final url =
        data['url']?.trim() ??
        data['h5_url']?.trim() ??
        data['h5Url']?.trim() ??
        notification.actionUrl;
    if ((type == 'h5' || type == 'webview' || type == 'web') &&
        url != null &&
        url.isNotEmpty) {
      _cancelPopupForCurrentRouteExit();
      if (openType == '2') {
        unawaited(_openFcmExternalUrl(url));
        return;
      }
      // 保留通知打开前的页面，物理返回键/返回手势应先回到来源页，
      // 而不是因 go() 替换路由后直接退出应用。
      router.push(
        RoutePaths.webviewLocation(url: url, title: notification.title),
      );
      return;
    }

    debugPrint('[FCM] Ignored notification tap with unsupported data: $data');
  }

  /// 通知离开首页/For You 时，关闭该位置的展示中、预加载中或请求中的弹框。
  /// 否则根路由上的 overlay 会覆盖通知的目标页面。
  void _cancelPopupForCurrentRouteExit() {
    _cancelAllPopupFlowsForRouteExit();
  }

  void _cancelAllPopupFlowsForRouteExit() {
    ref.read(popupEntryControllerProvider.notifier).cancelAllPlacementFlows();
  }

  void _trackPushNotificationOpen({
    required FcmNotification notification,
    required String? targetType,
    required String? dramaId,
  }) {
    final pushId =
        notification.id?.trim() ??
        notification.data['push_id']?.trim() ??
        notification.data['id']?.trim();
    if (pushId == null || pushId.isEmpty || targetType == null) return;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.pushNotificationOpen, {
              'push_id': pushId,
              'push_target_type': targetType,
              if (targetType == 'drama' &&
                  dramaId != null &&
                  dramaId.isNotEmpty)
                'drama_id': dramaId,
            }),
          ),
    );
  }

  void _preparePushEntrySource(FcmNotification notification) {
    final pushId =
        notification.id?.trim() ??
        notification.data['push_id']?.trim() ??
        notification.data['id']?.trim();
    _prepareEntrySource(type: 'push', id: pushId);
  }

  void _preparePopupEntrySource(PopupConfig popup) {
    _prepareEntrySource(type: 'popup', id: popup.id?.toString());
  }

  void _prepareEntrySource({required String type, String? id}) {
    if (type != 'share_deeplink' && (id == null || id.trim().isEmpty)) {
      debugPrint(
        '[Analytics] Entry source data-quality error: $type target is missing its stable ID.',
      );
      return;
    }
    ref.read(analyticsEntrySourceProvider.notifier).prepare(type: type, id: id);
  }

  bool _isSupportedFcmPage(String? rawPage) {
    return switch (rawPage?.trim().toLowerCase()) {
      'home' || 'recommend_tab' || 'member_tab' || 'recharge' => true,
      _ => false,
    };
  }

  void _openFcmPage(GoRouter router, String? rawPage) {
    switch (rawPage?.trim().toLowerCase()) {
      case 'home':
        router.go(RoutePaths.home);
        return;
      case 'recommend_tab':
        router.go(RoutePaths.forYou);
        return;
      case 'member_tab':
        router.go(RoutePaths.member);
        return;
      case 'reward_coin':
        router.go(RoutePaths.rewardsLocation());
        return;
      case 'member_point':
        router.go(RoutePaths.rewardsLocation(tab: RoutePaths.memberPointsTab));
        return;
      case 'member_open':
        router.push(RoutePaths.membership);
        return;
      case 'recharge':
        router.push(RoutePaths.store);
        return;
      default:
        debugPrint(
          '[FCM] Ignored notification tap with unsupported page: $rawPage',
        );
        return;
    }
  }

  Future<void> _openFcmExternalUrl(String url) async {
    final opened = await ref.read(externalUrlLauncherProvider).open(url);
    if (!opened) {
      debugPrint('[FCM] Failed to open external URL: $url');
    }
  }

  @override
  Future<bool> didPopRoute() async {
    if (ref.read(paymentLoadingControllerProvider).isVisible) {
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 生命周期埋点属于 App 级事件，不应因账号封禁等业务状态被跳过。
    debugPrint('[Analytics] App lifecycle changed: ${state.name}');
    unawaited(ref.read(appActiveReporterProvider).onLifecycleChanged(state));
    final analyticsLifecycleUpdate = ref
        .read(analyticsLifecycleTrackerProvider)
        .onLifecycleChanged(state);
    unawaited(analyticsLifecycleUpdate);
    final shareRewardChannel = ref
        .read(shareDramaRewardCoordinatorProvider)
        .onLifecycleChanged(state);
    if (shareRewardChannel == ShareDramaRewardChannel.facebook) {
      showAppCenterToast(_appLocalizations.shareRewardArrivalHint);
    }
    if (state == AppLifecycleState.resumed) {
      // 首次启动时 ADID 尚未生成或接口失败时，在回前台补偿绑定。
      unawaited(
        AdjustService(
          deviceIdentifierReporter: ref.read(
            adjustDeviceIdentifierReporterProvider,
          ),
        ).refreshDeviceIdentifiers(),
      );
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_flushAnalyticsAfterLifecycleUpdate(analyticsLifecycleUpdate));
    }
    final currentPlacement = ref.read(appShellBottomNavigationVisibleProvider)
        ? AppShellDestinations.popupPlacementForIndex(
            ref.read(appShellCurrentTabIndexProvider),
          )
        : null;
    unawaited(
      ref
          .read(popupEntryControllerProvider.notifier)
          .onLifecycleChanged(state, currentPlacement: currentPlacement),
    );
  }

  Future<void> _flushAnalyticsAfterLifecycleUpdate(
    Future<void> analyticsLifecycleUpdate,
  ) async {
    // 先确保 app_exit 已成功入队，再发送，避免切后台时漏掉最后一条事件。
    await analyticsLifecycleUpdate;
    await ref.read(analyticsUploadSinkProvider).flush();
  }

  Future<void> _setPreferredOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _bootstrapSessionAndI18n() async {
    try {
      debugPrint('[TokenInit] Starting token initialization...');
      startupLoadingTiming.mark('auth start');
      await ref.read(authControllerProvider.notifier).load();
      debugPrint('[TokenInit] AuthController.load() completed');
      startupLoadingTiming.mark('auth end');
      unawaited(_initializeStartupAnalytics());
      unawaited(_reportAppLaunchSafely());
      unawaited(_requestStartupPopupSafely());
    } catch (e, stackTrace) {
      debugPrint('[TokenInit] Token initialization failed: $e');
      debugPrint('[TokenInit] Stack trace: $stackTrace');
      // 鉴权失败也要释放首个 page_view；此时直接按当前可用公共参数上报。
      unawaited(_initializeStartupAnalytics());
    }

    if (!_startupAuthenticationReady.isCompleted) {
      _startupAuthenticationReady.complete();
    }

    // 认证完成后即可读取动态 Tab；标题尚未拿到远程语言包时会回退到客户端原文案，
    // 语言包加载完成后的状态更新会自动刷新标题，不让 i18n 阻塞首屏。
    unawaited(_loadBottomTabConfigWithStartupTiming());

    try {
      await ref.read(i18nInitializerProvider.future);
    } catch (e) {
      debugPrint('[I18n] I18n initialization trigger failed: $e');
    }
  }

  Future<void> _loadBottomTabConfigWithStartupTiming() async {
    startupLoadingTiming.mark('bottom-tabs start');
    await ref.read(bottomTabConfigControllerProvider.notifier).loadOnce();
    startupLoadingTiming.mark('bottom-tabs end');
  }

  /// 启动埋点的 userId 就绪策略：
  ///
  /// 1. 已有有效 token 且本地已恢复 userId，立即上报；
  /// 2. 有 token 但没有 userId，等待权益接口回写用户资料；
  /// 3. 权益接口失败或没有 token，不再阻塞启动埋点。
  ///
  /// 用户资料后续更新时，AnalyticsService 会在每个新事件创建时重新读取
  /// analyticsContextProvider，因此后续事件的公共参数会自动带上新的 userId。
  Future<void> _initializeStartupAnalytics() async {
    final token = ref.read(authTokenStoreProvider);
    if (token.hasAccessToken) {
      await ref.read(userInfoStoreProvider.notifier).waitForHydration();
      final userId = ref.read(userInfoStoreProvider).userId;
      if (userId == null || userId.isEmpty) {
        // AuthController.load 已并行发起同一刷新；这里等待自身的结果即可。
        // EntitlementController 会将请求失败转换为 false，故不会卡住启动埋点。
        await ref
            .read(entitlementControllerProvider.notifier)
            .refreshFromServer();
      }
    }

    if (!mounted) return;
    await ref.read(analyticsUploadSinkProvider).enableUploads();
    await ref.read(analyticsLifecycleTrackerProvider).onApplicationReady();
  }

  Future<void> _reportAppLaunchSafely() async {
    try {
      // 第一条启动活跃上报只等首页壳，不等待 FCM；避免 FCM 最长初始化时间导致
      // 活跃数据延迟或因用户快速退出而丢失。
      await startupLoadingTiming.waitForEnd();
      await ref
          .read(appActiveReporterProvider)
          .reportAppLaunch(includePushToken: false);
    } catch (e, stackTrace) {
      debugPrint('[AppActiveReporter] Launch report ignored: $e');
      debugPrint('[AppActiveReporter] Stack trace: $stackTrace');
    }
  }

  Future<void> _reportAppLaunchAfterFcmReady() async {
    final fcmInitialization = widget.fcmNotificationServiceFuture;
    if (fcmInitialization == null) {
      return;
    }
    final service = await fcmInitialization;
    if (service == null || !mounted) {
      return;
    }

    try {
      // FCM 服务初始化成功意味着 token 已完成一次读取；补发一条带 token 的上报。
      await _startupAuthenticationReady.future;
      if (!mounted) return;
      await startupLoadingTiming.waitForEnd();
      await ref.read(appActiveReporterProvider).reportAppLaunch();
    } catch (error, stackTrace) {
      debugPrint('[AppActiveReporter] FCM-ready launch report ignored: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _requestStartupPopupSafely() async {
    try {
      if (ref.read(accountBanControllerProvider).isBanned) {
        return;
      }
      final currentPlacement = AppShellDestinations.popupPlacementForIndex(
        ref.read(appShellCurrentTabIndexProvider),
      );
      if (currentPlacement == null) {
        return;
      }
      await ref
          .read(popupEntryControllerProvider.notifier)
          .requestForPlacement(currentPlacement);
    } catch (e, stackTrace) {
      debugPrint('[PopupEntryController] Startup popup ignored: $e');
      debugPrint('[PopupEntryController] Stack trace: $stackTrace');
    }
  }

  void _handlePopupImageTap(GoRouter router, PopupConfig popup) {
    _trackCampaignContentClick(popup);
    ref.read(popupEntryControllerProvider.notifier).tapActivePopupImage(popup);
    final contentMode = popup.contentMode;
    if (contentMode == 2) {
      _closePopupAndOpenDrama(router, popup);
      return;
    }

    if (contentMode != 1) {
      _dismissActivePopup();
      return;
    }

    switch (popup.jumpType) {
      case 1:
        _dismissActivePopup();
        return;
      case 2:
        _closePopupAndOpenWebView(router, popup);
        return;
      case 3:
        _closePopupAndOpenDrama(router, popup);
        return;
      case 4:
        _closePopupAndOpenPageCode(router, popup);
        return;
      default:
        _dismissActivePopup();
        return;
    }
  }

  void _handlePopupPlayTap(GoRouter router, PopupConfig popup) {
    _trackCampaignContentClick(popup);
    _closePopupAndOpenDrama(router, popup);
  }

  void _trackCampaignContentClick(PopupConfig popup) {
    final params = campaignContentClickParams(popup);
    if (params == null) {
      return;
    }
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(AnalyticsEvent(AnalyticsDefinitions.elementClick, params)),
    );
  }

  void _dismissActivePopup() {
    ref.read(popupEntryControllerProvider.notifier).dismissActivePopup();
  }

  void _finishActivePopupFlow() {
    ref.read(popupEntryControllerProvider.notifier).finishActivePopupFlow();
  }

  void _closePopupAndOpenWebView(GoRouter router, PopupConfig popup) {
    final url = popup.h5Url?.trim();
    if (url == null || url.isEmpty) {
      _dismissActivePopup();
      return;
    }
    _finishActivePopupFlow();
    if (popup.h5OpenType == 2) {
      unawaited(_openPopupExternalUrl(url));
      return;
    }
    // `/api/popup` 的配置名只用于弹框/埋点；内嵌 H5 不展示该名称作为页面标题。
    router.push(RoutePaths.webviewLocation(url: url));
  }

  Future<void> _openPopupExternalUrl(String url) async {
    final opened = await ref.read(externalUrlLauncherProvider).open(url);
    if (!opened) {
      debugPrint('[PopupEntryOverlay] Failed to open external URL: $url');
    }
  }

  void _closePopupAndOpenDrama(GoRouter router, PopupConfig popup) {
    final dramaId = popup.shortDramaId;
    if (dramaId == null || dramaId <= 0) {
      _dismissActivePopup();
      return;
    }
    _finishActivePopupFlow();
    _preparePopupEntrySource(popup);
    preparePlayerEntryPreload(
      context,
      dramaId: '$dramaId',
      episodeId: '1',
      trigger: 'popup',
    );
    router.push(
      RoutePaths.playerLocation(
        dramaId: '$dramaId',
        episodeId: '1',
        trigger: 'popup',
        userActionAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void _closePopupAndOpenPageCode(GoRouter router, PopupConfig popup) {
    final pageCode = popup.pageCode?.trim();
    switch (pageCode) {
      case 'home':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.go(RoutePaths.home);
        return;
      case 'recommend_tab':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.go(RoutePaths.forYou);
        return;
      case 'member_tab':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.go(RoutePaths.member);
        return;
      case 'member_open':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.push(RoutePaths.membership);
        return;
      case 'recharge':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.push(RoutePaths.store);
        return;
      case 'reward_coin':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.go(RoutePaths.rewardsLocation());
        return;
      case 'member_point':
        _finishActivePopupFlow();
        _preparePopupEntrySource(popup);
        router.go(RoutePaths.rewardsLocation(tab: RoutePaths.memberPointsTab));
        return;
      default:
        _dismissActivePopup();
        debugPrint('[PopupEntryOverlay] Unsupported page_code: $pageCode');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(featureSessionCleanupRegistrationProvider);
    ref.watch(channelConfigInitializerProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleControllerProvider);
    final supportedLocales = ref.watch(runtimeSupportedLocalesProvider);
    ref.watch(
      i18nControllerProvider.select(
        (state) => (state.languageCode, state.package?.version),
      ),
    );

    final botToastBuilder = BotToastInit();

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        final wrapped = botToastBuilder(context, child);
        final paymentLoading = ref.watch(paymentLoadingControllerProvider);
        final isPaymentLoading = paymentLoading.isVisible;
        final accountBan = ref.watch(accountBanControllerProvider);
        final isBanned = accountBan.isBanned;
        final paymentLoadingLabel = switch (paymentLoading.label) {
          PaymentLoadingLabel.none => null,
          PaymentLoadingLabel.loading => context.l10n.loading,
          PaymentLoadingLabel.confirmingPayment =>
            context.l10n.storePurchaseProcessing,
        };
        return StartupSplashGate(
          child: AccountBannedOverlay(
            child: PopScope(
              canPop:
                  !isPaymentLoading &&
                  (!isBanned || accountBan.isViewingFeedback),
              child: Stack(
                children: [
                  AppModalHost(child: wrapped),
                  if (!isBanned)
                    PopupEntryOverlay(
                      onImageTap: (popup) =>
                          _handlePopupImageTap(router, popup),
                      onPlayTap: (popup) => _handlePopupPlayTap(router, popup),
                    ),
                  if (isPaymentLoading && !isBanned)
                    AppBlockingLoadingOverlay(label: paymentLoadingLabel),
                  if (_isWaitingForExternalPlayerAuthentication && !isBanned)
                    AppBlockingLoadingOverlay(label: context.l10n.loading),
                ],
              ),
            ),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
