import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'bootstrap/app_modal_registry_bootstrap.dart';
import 'core/runtime/install_id_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        installIdStorageProvider.overrideWithValue(
          createSharedPreferencesInstallIdStorage(preferences),
        ),
        ...appModalRegistryOverrides,
      ],
      child: const DramaClientApp(),
    ),
  );
}
