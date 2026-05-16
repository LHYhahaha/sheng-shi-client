import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime/app_runtime_config.dart';
import '../../../core/runtime/app_runtime_config_provider.dart';
import '../application/player_performance_policy_provider.dart';
import '../domain/player_preload_config.dart';

/// 相邻预热与 session 窗口配置。
///
/// 基础值来自 [playerPerformancePolicyProvider]（含 ultraStable 的 0 session / 0 HLS）。
/// [appRuntimeConfigProvider] 可在**安全范围**内覆盖 HLS 数量与超时；**不会**把
/// ultraStable / low 档意外放大为高性能 preload 或 prepared/retained session。
///
/// 完整 [playerPerformancePolicyOverrideProvider] 仍最高，可显式放开（仅测试）。
final playerPreloadConfigProvider = Provider<PlayerPreloadConfig>((ref) {
  final policy = ref.watch(playerPerformancePolicyProvider);
  final base = policy.toPreloadConfig();
  final runtime = ref.watch(appRuntimeConfigProvider);
  return _mergePreloadConfig(base: base, runtime: runtime);
});

PlayerPreloadConfig _mergePreloadConfig({
  required PlayerPreloadConfig base,
  required AppRuntimeConfig runtime,
}) {
  final isUltraStable =
      base.effectivePreparedForwardSessionCount == 0 &&
      base.effectiveRetainedBackwardSessionCount == 0 &&
      base.forwardHlsPreloadCountFor(false) == 0;

  int mergeCount(int baseValue, int? runtimeValue) {
    if (runtimeValue == null) {
      return baseValue;
    }
    if (isUltraStable) {
      // 低端 ultraStable：禁止普通 runtime 把 HLS 预加载或 session 窗口撑大。
      return baseValue < runtimeValue ? baseValue : runtimeValue;
    }
    return runtimeValue;
  }

  return PlayerPreloadConfig(
    homeStartupPreloadCount: mergeCount(
      base.homeStartupPreloadCount,
      runtime.homeStartupPreloadCount,
    ),
    singleDramaForwardHlsPreloadCount: mergeCount(
      base.singleDramaForwardHlsPreloadCount,
      runtime.singleDramaForwardPreloadCount,
    ),
    singleDramaBackwardHlsPreloadCount: mergeCount(
      base.singleDramaBackwardHlsPreloadCount,
      runtime.singleDramaBackwardPreloadCount,
    ),
    forYouForwardHlsPreloadCount: mergeCount(
      base.forYouForwardHlsPreloadCount,
      runtime.forYouForwardPreloadCount,
    ),
    forYouBackwardHlsPreloadCount: mergeCount(
      base.forYouBackwardHlsPreloadCount,
      runtime.forYouBackwardPreloadCount,
    ),
    maxConcurrentHlsPreloads: base.maxConcurrentHlsPreloads,
    maxPreloadBytes: runtime.hlsMaxPreloadBytes ?? base.maxPreloadBytes,
    preloadTimeout: runtime.hlsPlaylistTimeout ?? base.preloadTimeout,
    preparedForwardSessionCount: base.preparedForwardSessionCount,
    retainedBackwardSessionCount: base.retainedBackwardSessionCount,
  );
}
