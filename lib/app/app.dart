import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/feature_session_cleanup.dart';
import '../bootstrap/i18n_bootstrap.dart';
import '../core/locale/app_locale_controller.dart';
import '../core/modal/app_modal_host.dart';
import '../core/network/api_client_provider.dart';
import '../features/auth/application/auth_controller.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// 应用根组件。
///
/// 这里组装主题、路由和固定语言包。业务页面不要自己创建 MaterialApp，否则 router、
/// locale 和 provider scope 会分裂。
class DramaClientApp extends ConsumerStatefulWidget {
  const DramaClientApp({super.key});

  @override
  ConsumerState<DramaClientApp> createState() => _DramaClientAppState();
}

class _DramaClientAppState extends ConsumerState<DramaClientApp> {
  @override
  void initState() {
    super.initState();
    _setPreferredOrientations();
    Future.microtask(_bootstrapSessionAndI18n);
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
      print('[TokenInit] ✅ AuthController.load() completed');
    } catch (e, stackTrace) {
      print('[TokenInit] ❌ Token initialization failed: $e');
      print('[TokenInit] Stack trace: $stackTrace');
    }

    try {
      await ref.read(i18nInitializerProvider.future);
    } catch (e) {
      print('[I18n] ⚠️ I18n initialization trigger failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(featureSessionCleanupRegistrationProvider);
    // 初始化渠道配置（从Android原生读取）
    ref.watch(channelConfigInitializerProvider);
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleControllerProvider);

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
        // BotToast 负责瞬态 toast；AppModalHost 负责阻塞式全局弹窗（O1 skeleton）。
        final wrapped = botToastBuilder(context, child);
        return AppModalHost(child: wrapped);
      },
      routerConfig: router,
    );
  }
}
