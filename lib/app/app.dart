import 'dart:async';

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
import '../core/account/account_ban_controller.dart';
import '../core/account/account_banned_overlay.dart';
import '../core/analytics/analytics_definition.dart';
import '../core/analytics/analytics_event.dart';
import '../core/analytics/analytics_lifecycle_tracker.dart';
import '../core/analytics/analytics_provider.dart';
import '../core/i18n/i18n.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/modal/app_modal_host.dart';
import '../core/network/api_client_provider.dart';
import '../core/notification/fcm_notification.dart';
import '../core/notification/fcm_notification_service.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/pay/application/payment_loading_controller.dart';
import '../features/popup/application/popup_entry_controller.dart';
import '../features/popup/application/popup_analytics.dart';
import '../features/popup/domain/popup.dart';
import '../features/popup/presentation/widgets/popup_entry_overlay.dart';
import '../l10n/app_localizations.dart';
import '../shared/url/external_url_launcher.dart';
import '../shared/widgets/app_blocking_loading_overlay.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';
import 'shell/app_shell.dart';
import 'shell/app_shell_chrome.dart';
import 'theme/app_theme.dart';

class DramaClientApp extends ConsumerStatefulWidget {
  const DramaClientApp({this.fcmNotificationService, super.key});

  final FcmNotificationService? fcmNotificationService;

  @override
  ConsumerState<DramaClientApp> createState() => _DramaClientAppState();
}

class _DramaClientAppState extends ConsumerState<DramaClientApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _appLinkSubscription;
  StreamSubscription<FcmNotification>? _fcmNotificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setPreferredOrientations();
    _listenForAppLinks();
    _listenForFcmNotificationTaps();
    Future.microtask(_bootstrapSessionAndI18n);
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    _fcmNotificationTapSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  void _handleAppLink(Uri uri) {
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    if (uri.scheme != 'novashort' || uri.host != 'player') {
      debugPrint('[AppLink] Ignored unsupported link: $uri');
      return;
    }

    final dramaId = uri.queryParameters['drama_id']?.trim();
    if (dramaId == null || dramaId.isEmpty) {
      debugPrint('[AppLink] Missing drama_id: $uri');
      return;
    }

    final location = RoutePaths.playerLocation(
      dramaId: dramaId,
      episodeId: '1',
      trigger: 'app_link',
      userActionAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    debugPrint('[AppLink] Opening drama $dramaId');
    ref.read(appRouterProvider).go(location);
  }

  void _listenForFcmNotificationTaps() {
    final service = widget.fcmNotificationService;
    if (service == null) return;
    _fcmNotificationTapSubscription = service.onNotificationTap.listen(
      _handleFcmNotificationTap,
    );
    final initialNotification = service.takeInitialNotificationTap();
    if (initialNotification != null) {
      Future.microtask(() => _handleFcmNotificationTap(initialNotification));
    }
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
      router.go(
        RoutePaths.playerLocation(
          dramaId: dramaId,
          episodeId: episodeId?.isNotEmpty == true ? episodeId! : '1',
          trigger: 'fcm_notification',
          userActionAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }

    // 当前客户端没有独立的短剧详情路由，详情通知进入该剧第一集的播放器。
    if ((type == 'drama' || type == 'drama_detail' || type == 'detail') &&
        dramaId != null &&
        dramaId.isNotEmpty) {
      router.go(
        RoutePaths.playerLocation(
          dramaId: dramaId,
          episodeId: '1',
          trigger: 'fcm_notification_detail',
          userActionAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }

    if (type == 'page') {
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
      if (openType == '2') {
        unawaited(_openFcmExternalUrl(url));
        return;
      }
      router.go(
        RoutePaths.webviewLocation(url: url, title: notification.title),
      );
      return;
    }

    debugPrint('[FCM] Ignored notification tap with unsupported data: $data');
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
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    unawaited(ref.read(appActiveReporterProvider).onLifecycleChanged(state));
    final analyticsLifecycleUpdate = ref
        .read(analyticsLifecycleTrackerProvider)
        .onLifecycleChanged(state);
    unawaited(analyticsLifecycleUpdate);
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
      await ref.read(authControllerProvider.notifier).load();
      debugPrint('[TokenInit] AuthController.load() completed');
      unawaited(
        ref.read(analyticsLifecycleTrackerProvider).onApplicationReady(),
      );
      unawaited(_reportAppLaunchSafely());
      unawaited(_requestStartupPopupSafely());
    } catch (e, stackTrace) {
      debugPrint('[TokenInit] Token initialization failed: $e');
      debugPrint('[TokenInit] Stack trace: $stackTrace');
      // 鉴权失败仍要释放首个 page_view；公共参数会按当前可用信息上报。
      unawaited(
        ref.read(analyticsLifecycleTrackerProvider).onApplicationReady(),
      );
    }

    try {
      await ref.read(i18nInitializerProvider.future);
    } catch (e) {
      debugPrint('[I18n] I18n initialization trigger failed: $e');
    }
  }

  Future<void> _reportAppLaunchSafely() async {
    try {
      await ref.read(appActiveReporterProvider).reportAppLaunch();
    } catch (e, stackTrace) {
      debugPrint('[AppActiveReporter] Launch report ignored: $e');
      debugPrint('[AppActiveReporter] Stack trace: $stackTrace');
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
    router.push(RoutePaths.webviewLocation(url: url, title: popup.name));
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
        router.go(RoutePaths.home);
        return;
      case 'recommend_tab':
        _finishActivePopupFlow();
        router.go(RoutePaths.forYou);
        return;
      case 'vip_tab':
        _finishActivePopupFlow();
        router.go(RoutePaths.member);
        return;
      case 'member_open':
        _finishActivePopupFlow();
        router.push(RoutePaths.membership);
        return;
      case 'recharge':
        _finishActivePopupFlow();
        router.push(RoutePaths.store);
        return;
      case 'reward_coin':
      case 'points':
        _finishActivePopupFlow();
        debugPrint('[PopupEntryOverlay] Reserved page_code: $pageCode');
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
      supportedLocales: AppLocalizations.supportedLocales,
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
        final paymentLoadingLabel =
            paymentLoading.label == PaymentLoadingLabel.loading
            ? context.l10n.loading
            : context.l10n.storePurchaseProcessing;
        return AccountBannedOverlay(
          child: PopScope(
            canPop:
                !isPaymentLoading &&
                (!isBanned || accountBan.isViewingFeedback),
            child: Stack(
              children: [
                AppModalHost(child: wrapped),
                if (!isBanned)
                  PopupEntryOverlay(
                    onImageTap: (popup) => _handlePopupImageTap(router, popup),
                    onPlayTap: (popup) => _handlePopupPlayTap(router, popup),
                  ),
                if (isPaymentLoading && !isBanned)
                  AppBlockingLoadingOverlay(label: paymentLoadingLabel),
              ],
            ),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
