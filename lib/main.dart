import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'bootstrap/app_modal_registry_bootstrap.dart';
import 'bootstrap/test_network_bootstrap.dart';
import 'core/auth/auth_token_storage_provider.dart';
import 'core/auth/flutter_secure_auth_token_storage.dart';
import 'core/network/test_network_config.dart';
import 'core/notification/fcm_notification_service.dart';
import 'core/runtime/install_id_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /*
   * 手动配置方式：
   * Android 会自动读取 android/app/google-services.json，
   * 所以这里不需要 firebase_options.dart。
  */
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(fcmBackgroundMessageHandler);
  final fcmNotificationService = FcmNotificationService();
  await fcmNotificationService.initialize();

  MediaKit.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final testNetworkConfig = TestNetworkConfigService.create(preferences);

  // 预加载 install id，确保登录时已准备好真实值
  final container = ProviderContainer(
    overrides: [
      installIdStorageProvider.overrideWithValue(
        createSharedPreferencesInstallIdStorage(preferences),
      ),
    ],
  );
  await container.read(installIdProvider.future);
  container.dispose();

  runApp(
    ProviderScope(
      overrides: [
        installIdStorageProvider.overrideWithValue(
          createSharedPreferencesInstallIdStorage(preferences),
        ),
        authTokenStorageProvider.overrideWithValue(
          FlutterSecureAuthTokenStorage(),
        ),
        testNetworkConfigProvider.overrideWithValue(testNetworkConfig),
        ...appModalRegistryOverrides,
      ],
      child: TestNetworkBootstrap(
        child: DramaClientApp(fcmNotificationService: fcmNotificationService),
      ),
    ),
  );
}
