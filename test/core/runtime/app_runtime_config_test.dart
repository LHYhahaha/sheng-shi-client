import 'package:drama_client/core/runtime/app_runtime_config.dart';
import 'package:drama_client/core/runtime/app_runtime_config_provider.dart';
import 'package:drama_client/core/runtime/device_capability.dart';
import 'package:drama_client/core/runtime/device_capability_provider.dart';
import 'package:drama_client/core/runtime/runtime_feature_flag_config.dart';
import 'package:drama_client/core/runtime/runtime_localization_config.dart';
import 'package:drama_client/core/runtime/runtime_performance_mode.dart';
import 'package:drama_client/core/runtime/runtime_player_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults 分组字段为本地安全默认值', () {
    const config = AppRuntimeConfig.defaults;
    expect(config.player.homeStartupHlsPreloadCount, 1);
    expect(config.player.hlsPlaylistTimeout, const Duration(seconds: 4));
    expect(config.player.performanceModeOverride, isNull);
    expect(config.localization.enableRemoteLanguagePack, isFalse);
    expect(config.localization.enableSubtitleByLocale, isFalse);
    expect(
      config.featureFlags.isEnabled(RuntimeFeatureFlagKeys.apiRemoteDrama),
      isFalse,
    );
  });

  test('low 设备规则收紧 player preload 字段', () {
    const lowDevice = DeviceCapability(
      platform: TargetPlatform.android,
      osVersion: 'unknown',
      deviceModel: 'test',
      manufacturer: 'unknown',
      performanceTier: DevicePerformanceTier.low,
    );
    const withHighPreload = AppRuntimeConfig(
      player: RuntimePlayerConfig(
        homeStartupHlsPreloadCount: 3,
        singleDramaForwardHlsPreloadCount: 2,
      ),
      localization: RuntimeLocalizationConfig.defaults,
      featureFlags: RuntimeFeatureFlagConfig.defaults,
    );
    final tightened = withHighPreload.withDeviceCapabilityRules(lowDevice);
    expect(tightened.player.homeStartupHlsPreloadCount, 0);
    expect(tightened.player.singleDramaForwardHlsPreloadCount, 0);
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
    expect(config.player.homeStartupHlsPreloadCount, 0);
    expect(container.read(appRuntimeRemoteConfigProvider), isNull);
  });

  test('remote merge 只覆盖非 null 字段且仍受 low 设备约束', () {
    final container = ProviderContainer(
      overrides: [
        devicePerformanceTierOverrideProvider.overrideWithValue(
          DevicePerformanceTier.low,
        ),
        appRuntimeRemoteConfigProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(
              homeStartupHlsPreloadCount: 5,
              performanceModeOverride: RuntimePerformanceMode.stable,
            ),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final config = container.read(appRuntimeConfigProvider);
    expect(config.player.homeStartupHlsPreloadCount, 0);
    expect(
      config.player.performanceModeOverride,
      RuntimePerformanceMode.stable,
    );
  });

  test('remote merge 缺字段不覆盖已有 player 默认值', () {
    const remote = AppRuntimeConfig(
      player: RuntimePlayerConfig(
        performanceModeOverride: RuntimePerformanceMode.rich,
      ),
      localization: RuntimeLocalizationConfig.defaults,
      featureFlags: RuntimeFeatureFlagConfig.defaults,
    );
    final merged = AppRuntimeConfig.defaults.mergeRemote(remote);
    expect(merged.player.performanceModeOverride, RuntimePerformanceMode.rich);
    expect(merged.player.homeStartupHlsPreloadCount, 1);
  });

  test('appRuntimeConfigOverrideProvider 优先级最高', () {
    final container = ProviderContainer(
      overrides: [
        appRuntimeRemoteConfigProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(homeStartupHlsPreloadCount: 2),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(homeStartupHlsPreloadCount: 9),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(appRuntimeConfigProvider)
          .player
          .homeStartupHlsPreloadCount,
      9,
    );
  });

  test('feature flag 显式 true 才开启', () {
    const config = RuntimeFeatureFlagConfig(
      flags: {RuntimeFeatureFlagKeys.remoteLocalization: true},
    );
    expect(config.isEnabled(RuntimeFeatureFlagKeys.remoteLocalization), isTrue);
    expect(
      config.isEnabled(RuntimeFeatureFlagKeys.playerLocalHlsProxy),
      isFalse,
    );
  });

  test('localization 默认不启用远程语言包与字幕跟随', () {
    const config = RuntimeLocalizationConfig.defaults;
    expect(config.enableRemoteLanguagePack, isFalse);
    expect(config.enableSubtitleByLocale, isFalse);
    expect(config.languagePackVersion, isNull);
  });
}
