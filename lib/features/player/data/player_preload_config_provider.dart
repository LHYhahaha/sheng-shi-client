import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/player_performance_policy_provider.dart';
import '../domain/player_preload_config.dart';

/// 相邻预热与 session 窗口配置，由 [playerPerformancePolicyProvider] 派生。
///
/// 不要在 controller 内硬编码数量，避免与低端策略分叉。
final playerPreloadConfigProvider = Provider<PlayerPreloadConfig>((ref) {
  return ref.watch(playerPerformancePolicyProvider).toPreloadConfig();
});
