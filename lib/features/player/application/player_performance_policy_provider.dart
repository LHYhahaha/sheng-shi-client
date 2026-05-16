import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_performance_policy.dart';

/// 测试或远程配置：直接覆盖完整 [PlayerPerformancePolicy]。
final playerPerformancePolicyOverrideProvider =
    Provider<PlayerPerformancePolicy?>((ref) => null);

/// 测试或远程配置：仅覆盖档位（rich / stable / ultraStable）。
final playerPerformanceModeOverrideProvider = Provider<PlayerPerformanceMode?>(
  (ref) => null,
);

/// 预留：未来按 RAM、Android API、brand、model 映射到 [PlayerPerformanceMode]。
///
/// 当前返回 null，表示仍走平台默认 + [playerPerformanceModeOverrideProvider]。
final playerPerformanceModeFromDeviceProvider =
    Provider<PlayerPerformanceMode?>((ref) {
      // TODO(low-end-policy): 接入 DeviceInfo / 远程配置后在此返回 ultraStable 等。
      return null;
    });

/// 当前播放体验性能策略。
///
/// 优先级：完整 policy override > 档位 override > 设备分级 > 平台默认。
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
  final deviceMode = ref.watch(playerPerformanceModeFromDeviceProvider);
  if (deviceMode != null) {
    return PlayerPerformancePolicy.forMode(deviceMode);
  }
  return PlayerPerformancePolicy.forPlatform(defaultTargetPlatform);
});
