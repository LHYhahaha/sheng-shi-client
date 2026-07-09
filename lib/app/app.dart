import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bootstrap/feature_session_cleanup.dart';
import '../bootstrap/i18n_bootstrap.dart';
import '../core/active/app_active_reporter.dart';
import '../core/i18n/i18n.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/modal/app_modal_host.dart';
import '../core/network/api_client_provider.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/pay/application/payment_loading_controller.dart';
import '../features/popup/application/popup_entry_controller.dart';
import '../features/popup/domain/popup.dart';
import '../features/popup/presentation/widgets/popup_entry_overlay.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/app_blocking_loading_overlay.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';

class DramaClientApp extends ConsumerStatefulWidget {
  const DramaClientApp({super.key});

  @override
  ConsumerState<DramaClientApp> createState() => _DramaClientAppState();
}

class _DramaClientAppState extends ConsumerState<DramaClientApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setPreferredOrientations();
    Future.microtask(_bootstrapSessionAndI18n);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    unawaited(ref.read(appActiveReporterProvider).onLifecycleChanged(state));
    final currentPlacement = AppShellDestinations.popupPlacementForIndex(
      ref.read(appShellCurrentTabIndexProvider),
    );
    unawaited(
      ref
          .read(popupEntryControllerProvider.notifier)
          .onLifecycleChanged(state, currentPlacement: currentPlacement),
    );
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
      unawaited(_reportAppLaunchSafely());
      unawaited(_requestStartupPopupSafely());
    } catch (e, stackTrace) {
      debugPrint('[TokenInit] Token initialization failed: $e');
      debugPrint('[TokenInit] Stack trace: $stackTrace');
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
    final contentMode = popup.contentMode;
    if (contentMode == 2) {
      _closePopupAndOpenDrama(router, popup);
      return;
    }

    if (contentMode != 1) {
      _closeActivePopup();
      return;
    }

    switch (popup.jumpType) {
      case 1:
        _closeActivePopup();
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
        _closeActivePopup();
        return;
    }
  }

  void _handlePopupPlayTap(GoRouter router, PopupConfig popup) {
    _closePopupAndOpenDrama(router, popup);
  }

  void _closeActivePopup() {
    ref.read(popupEntryControllerProvider.notifier).closeActivePopup();
  }

  void _finishActivePopupFlow() {
    ref.read(popupEntryControllerProvider.notifier).finishActivePopupFlow();
  }

  void _closePopupAndOpenWebView(GoRouter router, PopupConfig popup) {
    final url = popup.h5Url?.trim();
    if (url == null || url.isEmpty) {
      _closeActivePopup();
      return;
    }
    _finishActivePopupFlow();
    router.push(RoutePaths.webviewLocation(url: url, title: popup.name));
  }

  void _closePopupAndOpenDrama(GoRouter router, PopupConfig popup) {
    final dramaId = popup.shortDramaId;
    if (dramaId == null || dramaId <= 0) {
      _closeActivePopup();
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
      case 'vip_open':
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
        _closeActivePopup();
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
        final paymentLoadingLabel =
            paymentLoading.label == PaymentLoadingLabel.loading
            ? context.l10n.loading
            : context.l10n.storePurchaseProcessing;
        return PopScope(
          canPop: !isPaymentLoading,
          child: Stack(
            children: [
              AppModalHost(child: wrapped),
              PopupEntryOverlay(
                onImageTap: (popup) => _handlePopupImageTap(router, popup),
                onPlayTap: (popup) => _handlePopupPlayTap(router, popup),
              ),
              if (isPaymentLoading)
                AppBlockingLoadingOverlay(label: paymentLoadingLabel),
            ],
          ),
        );
      },
      routerConfig: router,
    );
  }
}
