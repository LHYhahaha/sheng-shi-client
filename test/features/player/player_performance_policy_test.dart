import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
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
    expect(policy.allowVideoSurfaceFollowDuringDrag, isFalse);
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
    expect(config.effectiveRetainedBackwardSessionCount, 1);
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
