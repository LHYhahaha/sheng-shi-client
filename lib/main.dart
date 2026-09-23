import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/presentation/widgets/novashort_splash_page.dart';
import 'bootstrap/app_modal_registry_bootstrap.dart';
import 'bootstrap/test_network_bootstrap.dart';
import 'core/auth/auth_token_storage_provider.dart';
import 'core/auth/flutter_secure_auth_token_storage.dart';
import 'core/active/app_active_reporter.dart';
import 'core/config/app_environment.dart';
import 'core/network/test_network_config.dart';
import 'core/notification/fcm_notification_service.dart';
import 'core/runtime/install_id_provider.dart';
import 'core/runtime/startup_loading_timing.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  runZoned(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      if (AppConfig.current.isProduction) {
        debugPrint = (_, {int? wrapWidth}) {};
      }
      final fcmServiceHandle = _FcmNotificationServiceHandle();
      final fcmNotificationService = Completer<FcmNotificationService?>();

      runApp(
        _StartupBootstrap(
          fcmServiceHandle: fcmServiceHandle,
          fcmNotificationService: fcmNotificationService,
        ),
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (!AppConfig.current.isProduction) {
          parent.print(zone, line);
        }
      },
    ),
  );
}

class _StartupBootstrap extends StatefulWidget {
  const _StartupBootstrap({
    required this.fcmServiceHandle,
    required this.fcmNotificationService,
  });

  final _FcmNotificationServiceHandle fcmServiceHandle;
  final Completer<FcmNotificationService?> fcmNotificationService;

  @override
  State<_StartupBootstrap> createState() => _StartupBootstrapState();
}

class _StartupBootstrapState extends State<_StartupBootstrap> {
  late final Future<SharedPreferences> _preferencesFuture;
  bool _nonCriticalSdksStarted = false;

  @override
  void initState() {
    super.initState();
    _preferencesFuture = SharedPreferences.getInstance();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _preferencesFuture,
      builder: (context, snapshot) {
        final preferences = snapshot.data;
        if (preferences == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            builder: (context, child) =>
                ScreenUtilInit(designSize: const Size(375, 812), child: child),
            home: const NovaShortSplashPage(),
          );
        }

        final testNetworkConfig = TestNetworkConfigService.create(preferences);
        return ProviderScope(
          overrides: [
            installIdStorageProvider.overrideWithValue(
              createSharedPreferencesInstallIdStorage(preferences),
            ),
            authTokenStorageProvider.overrideWithValue(
              FlutterSecureAuthTokenStorage(),
            ),
            testNetworkConfigProvider.overrideWithValue(testNetworkConfig),
            pushTokenReaderProvider.overrideWithValue(
              widget.fcmServiceHandle.getPushToken,
            ),
            ...appModalRegistryOverrides,
          ],
          child: TestNetworkBootstrap(
            onReady: _startNonCriticalSdks,
            child: DramaClientApp(
              fcmNotificationServiceFuture:
                  widget.fcmNotificationService.future,
            ),
          ),
        );
      },
    );
  }

  void _startNonCriticalSdks() {
    if (_nonCriticalSdksStarted) {
      return;
    }
    _nonCriticalSdksStarted = true;
    // 让抓包弹框或业务首屏先绘制完成，再初始化会占用平台线程的 SDK。
    unawaited(
      Future<void>(() async {
        final sdkStopwatch = Stopwatch()..start();
        debugPrint('[StartupSdk] MediaKit initialize start');
        MediaKit.ensureInitialized();
        debugPrint(
          '[StartupSdk] MediaKit initialize end '
          'elapsedMs=${sdkStopwatch.elapsedMilliseconds}',
        );
        unawaited(_initializeFcmAfterAppShell());
      }),
    );
  }

  Future<void> _initializeFcmAfterAppShell() async {
    await startupLoadingTiming.waitForEnd();
    final fcmStopwatch = Stopwatch()..start();
    debugPrint('[StartupSdk] FCM initialize start: app shell visible');
    final service = await _initializeFcmNotifications();
    debugPrint(
      '[StartupSdk] FCM initialize end '
      'elapsedMs=${fcmStopwatch.elapsedMilliseconds}',
    );
    widget.fcmServiceHandle.attach(service);
    widget.fcmNotificationService.complete(service);
  }
}

Future<String?> _unavailablePushToken() async => null;

/// 初始化失败时降级为无推送启动，不能阻塞应用进入首页。
Future<FcmNotificationService?> _initializeFcmNotifications() async {
  try {
    /*
     * 手动配置方式：
     * Android 会自动读取 android/app/google-services.json，
     * 所以这里不需要 firebase_options.dart。
     */
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);

    final service = FcmNotificationService();
    await service.initialize();
    return service;
  } catch (error, stackTrace) {
    debugPrint(
      '[FCM] Initialization failed; notifications are disabled: $error',
    );
    debugPrintStack(stackTrace: stackTrace);
    return null;
  }
}

/// 允许应用先启动；FCM 就绪后，后续活跃上报才带上 push token。
class _FcmNotificationServiceHandle {
  FcmNotificationService? _service;

  void attach(FcmNotificationService? service) {
    _service = service;
  }

  Future<String?> getPushToken() {
    final service = _service;
    return service?.getPushToken() ?? _unavailablePushToken();
  }
}
