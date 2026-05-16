import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_performance_policy.dart';

/// 测试用：覆盖默认平台策略。
final playerPerformancePolicyOverrideProvider =
    Provider<PlayerPerformancePolicy?>((ref) => null);

/// 当前播放体验性能策略。Android 默认 stable，iOS 默认 rich。
final playerPerformancePolicyProvider = Provider<PlayerPerformancePolicy>((
  ref,
) {
  final override = ref.watch(playerPerformancePolicyOverrideProvider);
  if (override != null) {
    return override;
  }
  return PlayerPerformancePolicy.forPlatform(defaultTargetPlatform);
});
