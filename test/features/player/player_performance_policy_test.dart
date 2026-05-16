import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
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
    expect(policy, PlayerPerformancePolicy.stable);
    expect(policy.allowVideoSurfaceFollowDuringDrag, isFalse);
    expect(policy.allowPressChromeDimming, isFalse);
  });

  test('iOS 默认 rich 策略', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final policy = container.read(playerPerformancePolicyProvider);
    expect(policy, PlayerPerformancePolicy.rich);
    expect(policy.allowVideoSurfaceFollowDuringDrag, isTrue);
    expect(policy.allowPressChromeDimming, isTrue);
  });

  test('provider 可被测试 override', () {
    final container = ProviderContainer(
      overrides: [
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          PlayerPerformancePolicy.stable,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerPerformancePolicyProvider),
      PlayerPerformancePolicy.stable,
    );
  });
}
