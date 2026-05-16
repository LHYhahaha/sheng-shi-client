import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_capability.dart';
import 'device_capability_probe.dart';

/// 测试 / debug：覆盖完整 [DeviceCapability]（优先级最高）。
final deviceCapabilityOverrideProvider = Provider<DeviceCapability?>(
  (ref) => null,
);

/// 仅覆盖性能档位（便于单测 low / high）。
final devicePerformanceTierOverrideProvider = Provider<DevicePerformanceTier?>(
  (ref) => null,
);

/// 启动时本地硬件探针结果（Phase B 前多为占位；可整段 override 做集成测试）。
final deviceHardwareSnapshotProvider = Provider<DeviceHardwareSnapshot>(
  (ref) => readLocalDeviceHardwareSnapshot(),
);

/// 当前设备能力（启动时一次性解析；不随运行中状态变化）。
final deviceCapabilityProvider = Provider<DeviceCapability>((ref) {
  final fullOverride = ref.watch(deviceCapabilityOverrideProvider);
  if (fullOverride != null) {
    return fullOverride;
  }

  final snapshot = ref.watch(deviceHardwareSnapshotProvider);
  final capability = DeviceCapability.resolve(
    platform: defaultTargetPlatform,
    manufacturer: snapshot.manufacturer,
    model: snapshot.model,
    osVersion: snapshot.osVersion,
    physicalMemoryMb: snapshot.physicalMemoryMb,
    processorCount: snapshot.processorCount,
  );

  final tierOverride = ref.watch(devicePerformanceTierOverrideProvider);
  if (tierOverride != null) {
    return capability.copyWith(performanceTier: tierOverride);
  }

  return capability;
});
