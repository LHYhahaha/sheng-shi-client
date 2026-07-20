import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
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
/// 否则优先透传平台设备 ID，保持真机/正式包的原始设备身份逻辑。
///
/// 仅在非 release 的 Android 模拟器上，如果 [FlutterUdid.udid] 返回 16 位
/// ANDROID_ID 这类非 UUID，才稳定映射成 UUID，避免开发联调被后端格式校验挡住。
/// logout / session cleanup **不会**清除 install id。
final installIdProvider = FutureProvider<String>((ref) async {
  const envOverride = String.fromEnvironment('API_DEVICE_ID');
  if (envOverride.isNotEmpty) {
    return envOverride;
  }

  try {
    final udid = await FlutterUdid.udid;
    if (udid != null && udid.isNotEmpty) {
      final deviceId = !_isUuid(udid) && await _isDevAndroidEmulator()
          ? _uuidFromDeviceSeed(udid)
          : udid;
      await ref.read(installIdStorageProvider).write(deviceId);
      return deviceId;
    }
  } catch (_) {
    // 获取失败或测试环境无 platform channel 时，回退到本地 install id。
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

bool _isUuid(String value) {
  final uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  return uuidRegex.hasMatch(value);
}

Future<bool> _isDevAndroidEmulator() async {
  if (kReleaseMode || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }

  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    return !androidInfo.isPhysicalDevice;
  } catch (_) {
    return false;
  }
}

String _uuidFromDeviceSeed(String seed) {
  final bytes = <int>[
    ..._fnv1a32(seed, 0),
    ..._fnv1a32(seed, 1),
    ..._fnv1a32(seed, 2),
    ..._fnv1a32(seed, 3),
  ];
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-'
      '${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}

List<int> _fnv1a32(String value, int salt) {
  var hash = 0x811c9dc5 ^ salt;
  for (final byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return [
    (hash >> 24) & 0xff,
    (hash >> 16) & 0xff,
    (hash >> 8) & 0xff,
    hash & 0xff,
  ];
}
