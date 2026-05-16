import 'package:flutter/foundation.dart';

import '../../../core/runtime/device_capability.dart';
import '../../../core/runtime/runtime_performance_mode.dart';
import '../domain/player_performance_policy.dart';

/// [RuntimePerformanceMode] → 播放器 domain 档位。
PlayerPerformanceMode playerPerformanceModeFromRuntime(
  RuntimePerformanceMode mode,
) {
  return switch (mode) {
    RuntimePerformanceMode.rich => PlayerPerformanceMode.rich,
    RuntimePerformanceMode.stable => PlayerPerformanceMode.stable,
    RuntimePerformanceMode.ultraStable => PlayerPerformanceMode.ultraStable,
  };
}

/// 由 [DeviceCapability.performanceTier] 推导 runtime 档位（不含 config / 测试 override）。
RuntimePerformanceMode runtimePerformanceModeForTier({
  required DevicePerformanceTier tier,
  required TargetPlatform platform,
}) {
  return switch (tier) {
    DevicePerformanceTier.low => RuntimePerformanceMode.ultraStable,
    DevicePerformanceTier.standard => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => RuntimePerformanceMode.rich,
      _ => RuntimePerformanceMode.stable,
    },
    DevicePerformanceTier.high => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => RuntimePerformanceMode.rich,
      _ => RuntimePerformanceMode.stable,
    },
  };
}
