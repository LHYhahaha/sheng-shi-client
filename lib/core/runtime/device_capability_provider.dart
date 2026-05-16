import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_capability.dart';

/// 测试 / debug：覆盖完整 [DeviceCapability]（优先级最高）。
final deviceCapabilityOverrideProvider = Provider<DeviceCapability?>(
  (ref) => null,
);

/// 仅覆盖性能档位（便于单测 low / high）。
final devicePerformanceTierOverrideProvider = Provider<DevicePerformanceTier?>(
  (ref) => null,
);

/// 当前设备能力（Phase A：平台 fallback，不阻塞启动）。
final deviceCapabilityProvider = Provider<DeviceCapability>((ref) {
  final fullOverride = ref.watch(deviceCapabilityOverrideProvider);
  if (fullOverride != null) {
    return fullOverride;
  }

  final tierOverride = ref.watch(devicePerformanceTierOverrideProvider);
  final fallback = DeviceCapability.fallbackForPlatform(defaultTargetPlatform);
  if (tierOverride != null) {
    return fallback.copyWith(performanceTier: tierOverride);
  }

  return fallback;
});
