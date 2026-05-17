import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/feature_session_cleanup.dart';
import '../core/locale/app_locale_controller.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// 应用根组件。
///
/// 这里组装主题、路由和固定语言包。业务页面不要自己创建 MaterialApp，否则 router、
/// locale 和 provider scope 会分裂。
class DramaClientApp extends ConsumerWidget {
  const DramaClientApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureSessionCleanupRegistrationProvider);
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
      builder: (context, child) => botToastBuilder(context, child),
      routerConfig: router,
    );
  }
}
