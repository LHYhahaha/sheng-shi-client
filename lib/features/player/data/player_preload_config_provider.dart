import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/runtime/app_runtime_config_provider.dart';
import '../../../core/runtime/runtime_player_config.dart';
import '../application/player_performance_policy_provider.dart';
import '../domain/player_preload_config.dart';

/// 播放器预加载与 session 窗口的**最终统一入口**。
///
/// HLS preloader、startup preload、playback preload 均从此 provider 读取。
///
/// 基础值来自 [playerPerformancePolicyProvider]（含 ultraStable 的 0 session / 0 HLS）。
/// [appRuntimeConfigProvider].player 可在安全范围内覆盖 HLS 数量与超时；
/// prepared/retained 仍仅由 policy cap，runtime 不能扩大 session window。
///
/// ultraStable / low 档：普通 remote 不能把 HLS 或 session 撑大。
/// 完整 [playerPerformancePolicyOverrideProvider] 仍最高（仅测试）。
final playerPreloadConfigProvider = Provider<PlayerPreloadConfig>((ref) {
  final policy = ref.watch(playerPerformancePolicyProvider);
  final base = policy.toPreloadConfig();
  final runtimePlayer = ref.watch(appRuntimeConfigProvider).player;
  final merged = _mergePreloadConfig(base: base, runtimePlayer: runtimePlayer);
  if (defaultTargetPlatform != TargetPlatform.android) {
    return merged;
  }

  // Android MediaCodec 的并发能力在不同厂商机型上差异很大，因此普通 stable
  // 只保留 previous/current/next 的最小窗口；low/ultraStable 仍会通过 policy
  // 变成 0，避免低端机持有额外播放器实例。
  final preparedSessionCount = merged.effectivePreparedForwardSessionCount > 0
      ? 1
      : 0;
  final retainedSessionCount = merged.effectiveRetainedBackwardSessionCount > 0
      ? 1
      : 0;
  return PlayerPreloadConfig(
    homeStartupPreloadCount: merged.homeStartupPreloadCount,
    singleDramaForwardHlsPreloadCount: merged.singleDramaForwardHlsPreloadCount,
    singleDramaBackwardHlsPreloadCount:
        merged.singleDramaBackwardHlsPreloadCount,
    forYouForwardHlsPreloadCount: merged.forYouForwardHlsPreloadCount,
    forYouBackwardHlsPreloadCount: merged.forYouBackwardHlsPreloadCount,
    maxConcurrentHlsPreloads: merged.maxConcurrentHlsPreloads,
    maxPreloadBytes: merged.maxPreloadBytes,
    preloadTimeout: merged.preloadTimeout,
    preparedForwardSessionCount: preparedSessionCount,
    retainedBackwardSessionCount: retainedSessionCount,
  );
});

PlayerPreloadConfig _mergePreloadConfig({
  required PlayerPreloadConfig base,
  required RuntimePlayerConfig runtimePlayer,
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
      // 低端 ultraStable：禁止普通 runtime 把 HLS 预加载撑大。
      return baseValue < runtimeValue ? baseValue : runtimeValue;
    }
    return runtimeValue;
  }

  int mergeBytes(int baseValue, int? runtimeValue) {
    if (runtimeValue == null) {
      return baseValue;
    }
    if (isUltraStable) {
      return baseValue < runtimeValue ? baseValue : runtimeValue;
    }
    return runtimeValue;
  }

  return PlayerPreloadConfig(
    homeStartupPreloadCount: mergeCount(
      base.homeStartupPreloadCount,
      runtimePlayer.homeStartupHlsPreloadCount,
    ),
    singleDramaForwardHlsPreloadCount: mergeCount(
      base.singleDramaForwardHlsPreloadCount,
      runtimePlayer.singleDramaForwardHlsPreloadCount,
    ),
    singleDramaBackwardHlsPreloadCount: mergeCount(
      base.singleDramaBackwardHlsPreloadCount,
      runtimePlayer.singleDramaBackwardHlsPreloadCount,
    ),
    forYouForwardHlsPreloadCount: mergeCount(
      base.forYouForwardHlsPreloadCount,
      runtimePlayer.forYouForwardHlsPreloadCount,
    ),
    forYouBackwardHlsPreloadCount: mergeCount(
      base.forYouBackwardHlsPreloadCount,
      runtimePlayer.forYouBackwardHlsPreloadCount,
    ),
    maxConcurrentHlsPreloads: base.maxConcurrentHlsPreloads,
    maxPreloadBytes: mergeBytes(
      base.maxPreloadBytes,
      runtimePlayer.hlsMaxPreloadBytes,
    ),
    preloadTimeout: runtimePlayer.hlsPlaylistTimeout ?? base.preloadTimeout,
    preparedForwardSessionCount: base.preparedForwardSessionCount,
    retainedBackwardSessionCount: base.retainedBackwardSessionCount,
  );
}
