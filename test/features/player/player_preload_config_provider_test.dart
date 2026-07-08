import 'package:drama_client/core/runtime/app_runtime_config.dart';
import 'package:drama_client/core/runtime/app_runtime_config_provider.dart';
import 'package:drama_client/core/runtime/device_capability.dart';
import 'package:drama_client/core/runtime/device_capability_provider.dart';
import 'package:drama_client/core/runtime/runtime_feature_flag_config.dart';
import 'package:drama_client/core/runtime/runtime_localization_config.dart';
import 'package:drama_client/core/runtime/runtime_player_config.dart';
import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
import 'package:drama_client/features/player/data/player_preload_config_provider.dart';
import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low 档 ultraStable 不被 runtime preload 撑大', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        devicePerformanceTierOverrideProvider.overrideWithValue(
          DevicePerformanceTier.low,
        ),
        appRuntimeRemoteConfigProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(
              homeStartupHlsPreloadCount: 5,
              singleDramaForwardHlsPreloadCount: 2,
              forYouForwardHlsPreloadCount: 2,
            ),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final config = container.read(playerPreloadConfigProvider);
    expect(config.effectivePreparedForwardSessionCount, 0);
    expect(config.effectiveRetainedBackwardSessionCount, 0);
    expect(config.forwardHlsPreloadCountFor(false), 0);
    expect(config.homeStartupPreloadCount, 0);
  });

  test('stable 档可接受 runtime 覆盖 HLS 数量与字节/超时', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(
              singleDramaForwardHlsPreloadCount: 0,
              hlsMaxPreloadBytes: 1024,
              hlsPlaylistTimeout: Duration(seconds: 8),
            ),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final config = container.read(playerPreloadConfigProvider);
    expect(
      container.read(playerPerformancePolicyProvider).mode,
      PlayerPerformanceMode.stable,
    );
    expect(config.forwardHlsPreloadCountFor(false), 0);
    expect(config.maxPreloadBytes, 1024);
    expect(config.preloadTimeout, const Duration(seconds: 8));
    expect(config.effectivePreparedForwardSessionCount, 1);
    expect(config.effectiveRetainedBackwardSessionCount, 1);
  });

  test('完整 policy override 仍可显式放开（测试）', () {
    final container = ProviderContainer(
      overrides: [
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          PlayerPerformancePolicy.stable,
        ),
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(homeStartupHlsPreloadCount: 0),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerPreloadConfigProvider).homeStartupPreloadCount,
      0,
    );
  });
}
