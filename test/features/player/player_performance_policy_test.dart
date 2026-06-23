import 'package:drama_client/core/runtime/app_runtime_config.dart';
import 'package:drama_client/core/runtime/app_runtime_config_provider.dart';
import 'package:drama_client/core/runtime/device_capability.dart';
import 'package:drama_client/core/runtime/device_capability_provider.dart';
import 'package:drama_client/core/runtime/runtime_feature_flag_config.dart';
import 'package:drama_client/core/runtime/runtime_localization_config.dart';
import 'package:drama_client/core/runtime/runtime_performance_mode.dart';
import 'package:drama_client/core/runtime/runtime_player_config.dart';
import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
import 'package:drama_client/features/player/application/runtime_performance_mode_mapper.dart';
import 'package:drama_client/features/player/data/player_preload_config_provider.dart';
import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('Android 默认 stable 策略', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final policy = container.read(playerPerformancePolicyProvider);
    expect(policy.mode, PlayerPerformanceMode.stable);
    expect(policy.allowVideoSurfaceVisibleDuringDrag, isTrue);
    expect(policy.allowVideoSurfaceFollowDuringDrag, isTrue);
    expect(policy.allowVideoSurfaceOpacityAnimationDuringDrag, isFalse);
    expect(policy.allowPressChromeDimming, isFalse);
    expect(policy.allowPlayPauseScaleFeedback, isFalse);
    expect(policy.allowRichTransitions, isFalse);
    expect(policy.preparedForwardSessionCount, 1);
    expect(policy.skipPreloadWhenCurrentItemLocked, isFalse);
  });

  test('iOS 默认 rich 策略', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final policy = container.read(playerPerformancePolicyProvider);
    expect(policy.mode, PlayerPerformanceMode.rich);
    expect(policy.allowVideoSurfaceVisibleDuringDrag, isTrue);
    expect(policy.allowVideoSurfaceFollowDuringDrag, isTrue);
    expect(policy.allowPressChromeDimming, isTrue);
  });

  test('完整 policy override', () {
    final container = ProviderContainer(
      overrides: [
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          PlayerPerformancePolicy.ultraStable,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider),
      PlayerPerformancePolicy.ultraStable,
    );
  });

  test('Android low 设备档 -> ultraStable', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        devicePerformanceTierOverrideProvider.overrideWithValue(
          DevicePerformanceTier.low,
        ),
      ],
    );
    addTearDown(container.dispose);

    final policy = container.read(playerPerformancePolicyProvider);
    expect(policy.mode, PlayerPerformanceMode.ultraStable);
    expect(policy.preparedForwardSessionCount, 0);
  });

  test('Android standard 设备档 -> stable', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider).mode,
      PlayerPerformanceMode.stable,
    );
  });

  test('iOS high 设备档 -> rich', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider).mode,
      PlayerPerformanceMode.rich,
    );
  });

  test('RuntimePerformanceMode 映射到 PlayerPerformancePolicy', () {
    expect(
      PlayerPerformancePolicy.forMode(
        playerPerformanceModeFromRuntime(RuntimePerformanceMode.rich),
      ).mode,
      PlayerPerformanceMode.rich,
    );
    expect(
      PlayerPerformancePolicy.forMode(
        playerPerformanceModeFromRuntime(RuntimePerformanceMode.stable),
      ).mode,
      PlayerPerformanceMode.stable,
    );
    expect(
      PlayerPerformancePolicy.forMode(
        playerPerformanceModeFromRuntime(RuntimePerformanceMode.ultraStable),
      ).mode,
      PlayerPerformanceMode.ultraStable,
    );
  });

  test('runtime config 覆盖播放器档位', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer(
      overrides: [
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(
              performanceModeOverride: RuntimePerformanceMode.rich,
            ),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider).mode,
      PlayerPerformanceMode.rich,
    );
  });

  test('完整 policy override 高于 runtime 档位', () {
    final container = ProviderContainer(
      overrides: [
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(
              performanceModeOverride: RuntimePerformanceMode.rich,
            ),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          PlayerPerformancePolicy.ultraStable,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider),
      PlayerPerformancePolicy.ultraStable,
    );
  });

  test('档位 override 高于 runtime 档位', () {
    final container = ProviderContainer(
      overrides: [
        appRuntimeConfigOverrideProvider.overrideWithValue(
          const AppRuntimeConfig(
            player: RuntimePlayerConfig(
              performanceModeOverride: RuntimePerformanceMode.rich,
            ),
            localization: RuntimeLocalizationConfig.defaults,
            featureFlags: RuntimeFeatureFlagConfig.defaults,
          ),
        ),
        playerPerformanceModeOverrideProvider.overrideWithValue(
          PlayerPerformanceMode.ultraStable,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider).mode,
      PlayerPerformanceMode.ultraStable,
    );
  });

  test('档位 override 可切 ultraStable', () {
    final container = ProviderContainer(
      overrides: [
        playerPerformanceModeOverrideProvider.overrideWithValue(
          PlayerPerformanceMode.ultraStable,
        ),
      ],
    );
    addTearDown(container.dispose);

    final policy = container.read(playerPerformancePolicyProvider);
    expect(policy.isUltraStable, isTrue);
    expect(policy.singleDramaForwardHlsPreloadCount, 0);
    expect(policy.retainedBackwardSessionCount, 0);
  });

  test('各档位拖动时 Video surface 可见性与跟手策略', () {
    expect(
      PlayerPerformancePolicy.rich.allowVideoSurfaceVisibleDuringDrag,
      isTrue,
    );
    expect(
      PlayerPerformancePolicy.rich.allowVideoSurfaceFollowDuringDrag,
      isTrue,
    );

    expect(
      PlayerPerformancePolicy.stable.allowVideoSurfaceVisibleDuringDrag,
      isTrue,
    );
    expect(
      PlayerPerformancePolicy.stable.allowVideoSurfaceFollowDuringDrag,
      isTrue,
    );
    expect(
      PlayerPerformancePolicy
          .stable
          .allowVideoSurfaceOpacityAnimationDuringDrag,
      isFalse,
    );
    expect(PlayerPerformancePolicy.stable.allowPressChromeDimming, isFalse);
    expect(PlayerPerformancePolicy.stable.allowPlayPauseScaleFeedback, isFalse);
    expect(PlayerPerformancePolicy.stable.allowRichTransitions, isFalse);

    expect(
      PlayerPerformancePolicy.ultraStable.allowVideoSurfaceVisibleDuringDrag,
      isFalse,
    );
    expect(
      PlayerPerformancePolicy.ultraStable.allowVideoSurfaceFollowDuringDrag,
      isFalse,
    );
  });

  test('各档位 seek 预览策略', () {
    expect(PlayerPerformancePolicy.rich.allowSeekThumbnailPreview, isTrue);
    expect(PlayerPerformancePolicy.rich.allowSeekTimeBubble, isTrue);
    expect(PlayerPerformancePolicy.rich.allowSeekPreviewShadow, isTrue);

    expect(PlayerPerformancePolicy.stable.allowSeekThumbnailPreview, isFalse);
    expect(PlayerPerformancePolicy.stable.allowSeekTimeBubble, isTrue);
    expect(PlayerPerformancePolicy.stable.allowSeekPreviewShadow, isFalse);

    expect(
      PlayerPerformancePolicy.ultraStable.allowSeekThumbnailPreview,
      isFalse,
    );
    expect(PlayerPerformancePolicy.ultraStable.allowSeekTimeBubble, isFalse);
    expect(PlayerPerformancePolicy.ultraStable.allowSeekPreviewShadow, isFalse);
  });

  test('ultraStable 派生保守 PlayerPreloadConfig', () {
    final config = PlayerPerformancePolicy.ultraStable.toPreloadConfig();
    expect(config.effectivePreparedForwardSessionCount, 0);
    expect(config.effectiveRetainedBackwardSessionCount, 0);
    expect(config.forwardHlsPreloadCountFor(false), 0);
    expect(config.backwardHlsPreloadCountFor(false), 0);
  });

  test('stable 派生 preload 仍为最小可用窗口', () {
    final config = PlayerPerformancePolicy.stable.toPreloadConfig();
    expect(config.effectivePreparedForwardSessionCount, 1);
    expect(config.effectiveRetainedBackwardSessionCount, 10);
    expect(config.forwardHlsPreloadCountFor(true), 1);
  });

  test('playerPreloadConfigProvider 跟随 policy', () {
    final container = ProviderContainer(
      overrides: [
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          PlayerPerformancePolicy.ultraStable,
        ),
      ],
    );
    addTearDown(container.dispose);

    final config = container.read(playerPreloadConfigProvider);
    expect(config.effectivePreparedForwardSessionCount, 0);
    expect(config.effectiveRetainedBackwardSessionCount, 0);
  });
}
