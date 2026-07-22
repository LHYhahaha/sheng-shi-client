import 'package:drama_client/app/app.dart';
import 'package:drama_client/app/app_root_navigator_key.dart';
import 'package:drama_client/bootstrap/app_modal_registry_bootstrap.dart';
import 'package:drama_client/core/active/app_active_reporter.dart';
import 'package:drama_client/core/modal/app_modal_host.dart';
import 'package:drama_client/core/notification/startup_notification_permission_reporter.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

/// 与生产一致的 [DramaClientApp]，并注入 modal presenter registry。
Widget buildDramaClientAppForTest({List overrides = const []}) {
  registerFallbackValue(AppLifecycleState.resumed);
  final activeReporter = _MockAppActiveReporter();
  final notificationPermissionReporter =
      _MockStartupNotificationPermissionReporter();
  when(activeReporter.reportAppLaunch).thenAnswer((_) async {});
  when(() => activeReporter.onLifecycleChanged(any())).thenAnswer((_) async {});
  when(
    notificationPermissionReporter.checkAndReportOnHomeArrival,
  ).thenAnswer((_) async {});
  return ProviderScope(
    overrides: [
      ...appModalRegistryOverrides,
      appActiveReporterProvider.overrideWithValue(activeReporter),
      startupNotificationPermissionReporterProvider.overrideWithValue(
        notificationPermissionReporter,
      ),
      ...overrides,
    ],
    child: const DramaClientApp(),
  );
}

class _MockAppActiveReporter extends Mock implements AppActiveReporter {}

class _MockStartupNotificationPermissionReporter extends Mock
    implements StartupNotificationPermissionReporter {}

/// 为 Store/Membership 等页面测试挂载 [AppModalHost] 与 presenter registry。
Widget buildAppModalTestApp({required Widget home, List overrides = const []}) {
  return ProviderScope(
    overrides: [...appModalRegistryOverrides, ...overrides],
    child: MaterialApp(
      navigatorKey: appRootNavigatorKey,
      builder: (context, child) => AppModalHost(child: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}
