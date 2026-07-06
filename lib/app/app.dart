import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/feature_session_cleanup.dart';
import '../bootstrap/i18n_bootstrap.dart';
import '../core/active/app_active_reporter.dart';
import '../core/i18n/i18n.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/modal/app_modal_host.dart';
import '../core/network/api_client_provider.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/pay/application/payment_loading_controller.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/app_blocking_loading_overlay.dart';
import 'router/app_router.dart';
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
    ref.read(appActiveReporterProvider).onLifecycleChanged(state);
  }

  Future<void> _setPreferredOrientations() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _bootstrapSessionAndI18n() async {
    try {
      print('[TokenInit] Starting token initialization...');
      await ref.read(authControllerProvider.notifier).load();
      print('[TokenInit] AuthController.load() completed');
      await ref.read(appActiveReporterProvider).reportAppLaunch();
    } catch (e, stackTrace) {
      print('[TokenInit] Token initialization failed: $e');
      print('[TokenInit] Stack trace: $stackTrace');
    }

    try {
      await ref.read(i18nInitializerProvider.future);
    } catch (e) {
      print('[I18n] I18n initialization trigger failed: $e');
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
