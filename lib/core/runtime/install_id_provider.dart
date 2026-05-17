import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'in_memory_install_id_storage.dart';
import 'install_id_generator.dart';
import 'install_id_storage.dart';
import 'shared_preferences_install_id_storage.dart';

export 'install_id_storage.dart';

/// 默认 in-memory；[main] 应 override 为 [SharedPreferencesInstallIdStorage]。
final installIdStorageProvider = Provider<InstallIdStorage>(
  (ref) => InMemoryInstallIdStorage(),
);

/// 稳定安装级 Device-Id 来源，供 [apiRequestContextProvider] 与 guest bootstrap 使用。
///
/// 优先 `dart-define=API_DEVICE_ID`（联调/测试）；否则读持久化 install id，缺失则生成
/// UUID 并写入。logout / session cleanup **不会**清除 install id。
final installIdProvider = FutureProvider<String>((ref) async {
  const envOverride = String.fromEnvironment('API_DEVICE_ID');
  if (envOverride.isNotEmpty) {
    return envOverride;
  }

  final storage = ref.read(installIdStorageProvider);
  final existing = await storage.read();
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }

  final installId = generateInstallId();
  await storage.write(installId);
  return installId;
});

/// 生产启动时绑定 [SharedPreferences] 的便捷方法（在 [main] 调用）。
InstallIdStorage createSharedPreferencesInstallIdStorage(
  SharedPreferences preferences,
) {
  return SharedPreferencesInstallIdStorage(preferences);
}
