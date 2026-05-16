import 'package:flutter/foundation.dart';

import '../../features/player/domain/player_performance_policy.dart';
import 'device_capability.dart';

/// 由 [DeviceCapability.performanceTier] 推导播放器档位（不含 runtime / 测试 override）。
PlayerPerformanceMode playerPerformanceModeForTier({
  required DevicePerformanceTier tier,
  required TargetPlatform platform,
}) {
  return switch (tier) {
    DevicePerformanceTier.low => PlayerPerformanceMode.ultraStable,
    DevicePerformanceTier.standard => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => PlayerPerformanceMode.rich,
      _ => PlayerPerformanceMode.stable,
    },
    DevicePerformanceTier.high => switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => PlayerPerformanceMode.rich,
      _ => PlayerPerformanceMode.stable,
    },
  };
}
