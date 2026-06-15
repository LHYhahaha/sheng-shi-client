import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_udid/flutter_udid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'in_memory_install_id_storage.dart';
import 'install_id_generator.dart';
import 'install_id_storage.dart';
import 'shared_preferences_install_id_storage.dart';

export 'install_id_storage.dart';

final installIdStorageProvider = Provider<InstallIdStorage>(
  (ref) => InMemoryInstallIdStorage(),
);

/// 稳定安装级 Device-Id 来源，供 [apiRequestContextProvider] 与 guest bootstrap 使用。
///
/// 优先 `dart-define=API_DEVICE_ID`（联调/测试）；
/// 否则使用 [FlutterUdid.udid] 获取持久化设备 ID（卸载后不变）；
/// 如果获取失败，回退到持久化 install id，缺失则生成 UUID 并写入。
/// logout / session cleanup **不会**清除 install id。
final installIdProvider = FutureProvider<String>((ref) async {
  const envOverride = String.fromEnvironment('API_DEVICE_ID');
  if (envOverride.isNotEmpty) {
    return envOverride;
  }

  // 使用 flutter_udid 获取持久化的设备 ID（卸载后不变）
  try {
    final udid = await FlutterUdid.udid;
    if (udid != null && udid.isNotEmpty) {
      return udid;
    }
  } on PlatformException catch (_) {
    // 获取失败，回退到原有逻辑
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
