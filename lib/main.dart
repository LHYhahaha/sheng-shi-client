import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'bootstrap/app_modal_registry_bootstrap.dart';
import 'core/auth/auth_token_storage_provider.dart';
import 'core/auth/flutter_secure_auth_token_storage.dart';
import 'core/network/system_proxy_config.dart';
import 'core/runtime/install_id_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await SystemProxyConfigService.initialize();

  final preferences = await SharedPreferences.getInstance();

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
        ...appModalRegistryOverrides,
      ],
      child: const DramaClientApp(),
    ),
  );
}
