import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
  final platformDeviceId = await _readPlatformDeviceUuid();
  if (platformDeviceId != null) {
    await storage.write(platformDeviceId);
    return platformDeviceId;
  }

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

const _deviceUuidChannel = MethodChannel('com.yushi.drama/device_uuid');

Future<String?> _readPlatformDeviceUuid() async {
  try {
    final seed = await _deviceUuidChannel.invokeMethod<String>('getDeviceSeed');
    if (seed == null || seed.isEmpty) {
      return null;
    }
    return _uuidFromStableSeed(seed);
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

String _uuidFromStableSeed(String seed) {
  final bytes = List<int>.generate(16, (index) => index * 17);
  for (var i = 0; i < seed.length; i += 1) {
    final code = seed.codeUnitAt(i);
    final slot = i % bytes.length;
    bytes[slot] = (bytes[slot] ^ code ^ (i * 31)) & 0xff;
    bytes[(slot + 7) % bytes.length] =
        (bytes[(slot + 7) % bytes.length] + code + i) & 0xff;
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-'
      '${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}
