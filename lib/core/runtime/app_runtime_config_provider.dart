import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_runtime_config.dart';
import 'device_capability_provider.dart';

/// 测试 / debug：覆盖合并后的完整 [AppRuntimeConfig]（最高优先级）。
final appRuntimeConfigOverrideProvider = Provider<AppRuntimeConfig?>(
  (ref) => null,
);

/// 远程配置片段（Phase A：恒为 null；失败不影响启动）。
///
/// Phase D 将在此接入 repository fetch；解析失败时应保持 null 并回退本地默认。
final appRuntimeRemoteConfigProvider = Provider<AppRuntimeConfig?>((ref) {
  return null;
});

/// 合并后的全局 runtime 配置。
///
/// 优先级（低 → 高）：
/// 1. [AppRuntimeConfig.defaults]
/// 2. [deviceCapabilityProvider] 规则（低端收紧 preload）
/// 3. [appRuntimeRemoteConfigProvider]（有值时 merge）
/// 4. [appRuntimeConfigOverrideProvider]（测试 / debug）
final appRuntimeConfigProvider = Provider<AppRuntimeConfig>((ref) {
  final testOverride = ref.watch(appRuntimeConfigOverrideProvider);
  if (testOverride != null) {
    return testOverride;
  }

  final device = ref.watch(deviceCapabilityProvider);
  var config = AppRuntimeConfig.defaults.withDeviceCapabilityRules(device);

  final remote = ref.watch(appRuntimeRemoteConfigProvider);
  if (remote != null) {
    config = config.mergeRemote(remote).withDeviceCapabilityRules(device);
  }

  return config;
});
