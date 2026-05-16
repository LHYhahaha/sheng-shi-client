import 'package:flutter/foundation.dart';

import 'device_capability.dart';

/// 启动时一次性本地设备分级（保守 denylist + 可选 RAM）。
///
/// 不是完整性能数据库；未命中名单且 RAM 未知时 Android 保持 [DevicePerformanceTier.standard]。
/// iOS 不自动降级。运行中不重新计算；远程/测试 override 仍可覆盖。
DevicePerformanceTier resolveDevicePerformanceTier({
  required TargetPlatform platform,
  String? manufacturer,
  String? model,
  String? osVersion,
  int? physicalMemoryMb,
  int? processorCount,
}) {
  // [processorCount] / [osVersion] 预留 Phase B 诊断，不参与 low 判定。
  assert(() {
    processorCount;
    osVersion;
    return true;
  }());

  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => DevicePerformanceTier.high,
    TargetPlatform.android => _resolveAndroidTier(
      manufacturer: manufacturer,
      model: model,
      physicalMemoryMb: physicalMemoryMb,
    ),
    _ => DevicePerformanceTier.standard,
  };
}

DevicePerformanceTier _resolveAndroidTier({
  String? manufacturer,
  String? model,
  int? physicalMemoryMb,
}) {
  if (physicalMemoryMb != null) {
    if (physicalMemoryMb <= 3072) {
      return DevicePerformanceTier.low;
    }
    if (physicalMemoryMb >= 6144) {
      // >= 6GB：保守保持 standard，不自动 high。
      return DevicePerformanceTier.standard;
    }
    // 约 4GB（3072–6144 之间）：standard。
  }

  if (_matchesKnownLowEndAndroid(manufacturer: manufacturer, model: model)) {
    return DevicePerformanceTier.low;
  }

  return DevicePerformanceTier.standard;
}

/// 保守 denylist：仅覆盖已验证卡顿的 Samsung Galaxy A14 / SM-A145 系列。
///
/// 大小写不敏感。`unknown` / `android-generic` 等占位符不触发 low。
/// 完整型号读取 defer 到 Phase B（`device_info_plus` 等），届时仍调用本函数。
bool _matchesKnownLowEndAndroid({String? manufacturer, String? model}) {
  final normalizedManufacturer = _normalizeHardwareToken(manufacturer);
  final normalizedModel = _normalizeHardwareToken(model);

  if (!_hasActionableHardwareIdentity(
    normalizedManufacturer,
    normalizedModel,
  )) {
    return false;
  }

  final haystack = '$normalizedManufacturer $normalizedModel'.trim();

  for (final pattern in _lowEndAndroidModelPatterns) {
    if (pattern.hasMatch(haystack)) {
      return true;
    }
  }
  return false;
}

/// 已知低端 Android 型号模式（denylist，非完整数据库）。
final List<RegExp> _lowEndAndroidModelPatterns = [
  // Samsung SM-A145*（如 SM-A145F）。
  RegExp(r'sm-a145', caseSensitive: false),
  // Samsung SM-A14* 字母后缀变体（如 SM-A14F）；不匹配 SM-A146 等三位数字系列。
  RegExp(r'sm-a14(?=[a-z]|$)', caseSensitive: false),
  // 市场名 Galaxy A14。
  RegExp(r'galaxy\s*a14', caseSensitive: false),
];

bool _hasActionableHardwareIdentity(String manufacturer, String model) {
  const placeholders = {'unknown', 'android-generic', 'generic', ''};
  final hasManufacturer =
      manufacturer.isNotEmpty && !placeholders.contains(manufacturer);
  final hasModel = model.isNotEmpty && !placeholders.contains(model);
  return hasManufacturer || hasModel;
}

String _normalizeHardwareToken(String? value) {
  return value?.trim().toLowerCase() ?? '';
}
