import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime/app_runtime_config_provider.dart';
import '../../../core/runtime/device_capability_provider.dart';
import '../../../core/runtime/player_performance_mode_for_device.dart';
import '../domain/player_performance_policy.dart';

/// 测试或远程配置：直接覆盖完整 [PlayerPerformancePolicy]（最高）。
final playerPerformancePolicyOverrideProvider =
    Provider<PlayerPerformancePolicy?>((ref) => null);

/// 测试或 debug：仅覆盖档位（rich / stable / ultraStable）。
final playerPerformanceModeOverrideProvider = Provider<PlayerPerformanceMode?>(
  (ref) => null,
);

/// 由全局 [deviceCapabilityProvider] 推导播放器档位。
final playerPerformanceModeFromDeviceProvider =
    Provider<PlayerPerformanceMode?>((ref) {
      final device = ref.watch(deviceCapabilityProvider);
      return playerPerformanceModeForTier(
        tier: device.performanceTier,
        platform: device.platform,
      );
    });

/// 当前播放体验性能策略。
///
/// 优先级（低 → 高）：
/// 1. 平台默认 [PlayerPerformancePolicy.forPlatform]
/// 2. [playerPerformanceModeFromDeviceProvider]（设备档位）
/// 3. [appRuntimeConfigProvider.playerPerformanceModeOverride]（runtime 配置）
/// 4. [playerPerformanceModeOverrideProvider]（测试 / debug 档位）
/// 5. [playerPerformancePolicyOverrideProvider]（测试 / debug 完整 policy）
final playerPerformancePolicyProvider = Provider<PlayerPerformancePolicy>((
  ref,
) {
  final policyOverride = ref.watch(playerPerformancePolicyOverrideProvider);
  if (policyOverride != null) {
    return policyOverride;
  }

  final modeOverride = ref.watch(playerPerformanceModeOverrideProvider);
  if (modeOverride != null) {
    return PlayerPerformancePolicy.forMode(modeOverride);
  }

  final runtimeMode = ref
      .watch(appRuntimeConfigProvider)
      .playerPerformanceModeOverride;
  if (runtimeMode != null) {
    return PlayerPerformancePolicy.forMode(runtimeMode);
  }

  final deviceMode = ref.watch(playerPerformanceModeFromDeviceProvider);
  if (deviceMode != null) {
    return PlayerPerformancePolicy.forMode(deviceMode);
  }

  return PlayerPerformancePolicy.forPlatform(defaultTargetPlatform);
});
