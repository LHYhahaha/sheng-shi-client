import 'package:flutter/foundation.dart';

/// 启动时本地硬件快照（Phase B 前多为占位符；规则仍对显式 model 生效）。
class DeviceHardwareSnapshot {
  const DeviceHardwareSnapshot({
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    this.physicalMemoryMb,
    this.processorCount,
  });

  final String manufacturer;
  final String model;
  final String osVersion;
  final int? physicalMemoryMb;
  final int? processorCount;
}

/// 读取当前设备硬件信息（同步、仅调用一次）。
///
/// Phase B：在此接入 `device_info_plus` / platform channel，填充真实
/// manufacturer/model/RAM。
///
/// 可选 `--dart-define=DEVICE_MODEL` / `DEVICE_MANUFACTURER` 供真机脚本注入型号
///（不替代 Phase B 自动读取）。
DeviceHardwareSnapshot readLocalDeviceHardwareSnapshot() {
  const modelDefine = String.fromEnvironment('DEVICE_MODEL');
  const manufacturerDefine = String.fromEnvironment('DEVICE_MANUFACTURER');

  if (modelDefine.isNotEmpty) {
    return DeviceHardwareSnapshot(
      manufacturer: manufacturerDefine.isEmpty ? 'unknown' : manufacturerDefine,
      model: modelDefine,
      osVersion: 'unknown',
      physicalMemoryMb: _memoryMbFromDefine(),
      processorCount: null,
    );
  }

  return DeviceHardwareSnapshot(
    manufacturer: 'unknown',
    model: _placeholderModel(defaultTargetPlatform),
    osVersion: 'unknown',
    physicalMemoryMb: null,
    processorCount: null,
  );
}

int? _memoryMbFromDefine() {
  const raw = String.fromEnvironment('DEVICE_PHYSICAL_MEMORY_MB');
  if (raw.isEmpty) {
    return null;
  }
  return int.tryParse(raw);
}

String _placeholderModel(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android => 'android-generic',
    TargetPlatform.iOS => 'ios-generic',
    TargetPlatform.macOS => 'macos-generic',
    _ => 'unknown',
  };
}
