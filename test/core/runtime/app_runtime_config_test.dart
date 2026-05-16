import 'package:drama_client/core/runtime/app_runtime_config.dart';
import 'package:drama_client/core/runtime/app_runtime_config_provider.dart';
import 'package:drama_client/core/runtime/device_capability.dart';
import 'package:drama_client/core/runtime/device_capability_provider.dart';
import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults 为本地安全默认值', () {
    const config = AppRuntimeConfig.defaults;
    expect(config.homeStartupPreloadCount, 1);
    expect(config.hlsPlaylistTimeout, const Duration(seconds: 4));
    expect(config.playerPerformanceModeOverride, isNull);
    expect(config.enableRemoteLocalization, isFalse);
  });

  test('low 设备规则收紧 preload 字段', () {
    const lowDevice = DeviceCapability(
      platform: TargetPlatform.android,
      osVersion: 'unknown',
      deviceModel: 'test',
      manufacturer: 'unknown',
      performanceTier: DevicePerformanceTier.low,
    );
    const withHighPreload = AppRuntimeConfig(
      homeStartupPreloadCount: 3,
      singleDramaForwardPreloadCount: 2,
    );
    final tightened = withHighPreload.withDeviceCapabilityRules(lowDevice);
    expect(tightened.homeStartupPreloadCount, 0);
    expect(tightened.singleDramaForwardPreloadCount, 0);
  });

  test('remote 缺失时使用 defaults + 设备规则', () {
    final container = ProviderContainer(
      overrides: [
        devicePerformanceTierOverrideProvider.overrideWithValue(
          DevicePerformanceTier.low,
        ),
      ],
    );
    addTearDown(container.dispose);

    final config = container.read(appRuntimeConfigProvider);
    expect(config.homeStartupPreloadCount, 0);
    expect(container.read(appRuntimeRemoteConfigProvider), isNull);
  });

  test('remote merge 后仍受 low 设备规则约束', () {
    final container = ProviderContainer(
      overrides: [
        devicePerformanceTierOverrideProvider.overrideWithValue(
          DevicePerformanceTier.low,
        ),
        appRuntimeRemoteConfigProvider.overrideWithValue(
          const AppRuntimeConfig(
            homeStartupPreloadCount: 5,
            playerPerformanceModeOverride: PlayerPerformanceMode.stable,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final config = container.read(appRuntimeConfigProvider);
    expect(config.homeStartupPreloadCount, 0);
    expect(config.playerPerformanceModeOverride, PlayerPerformanceMode.stable);
  });

  test('appRuntimeConfigOverrideProvider 优先级最高', () {
    final container = ProviderContainer(
      overrides: [
        appRuntimeRemoteConfigProvider.overrideWithValue(
          const AppRuntimeConfig(homeStartupPreloadCount: 2),
        ),
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(homeStartupPreloadCount: 9),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appRuntimeConfigProvider).homeStartupPreloadCount, 9);
  });
}
