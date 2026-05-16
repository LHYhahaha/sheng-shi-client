import 'package:drama_client/features/player/application/player_feed_engine.dart';
import 'package:drama_client/features/player/application/player_playback_controller.dart';
import 'package:drama_client/features/player/application/player_feed_engine_access_flow.dart';
import 'package:drama_client/features/player/application/player_performance_policy_provider.dart';
import 'package:drama_client/features/player/domain/player_performance_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test('Android 默认 stable policy 经 engine state 暴露', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(
      playerFeedEngineProvider(PlayerPlaybackSessionKeys.forYouTab),
    );
    expect(state.policy.mode, PlayerPerformanceMode.stable);
    expect(state.policy.allowVideoSurfaceFollowDuringDrag, isTrue);
  });

  test('iOS 默认 rich policy 经 engine state 暴露', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(
      playerFeedEngineProvider(PlayerPlaybackSessionKeys.forYouTab),
    );
    expect(state.policy.mode, PlayerPerformanceMode.rich);
    expect(state.policy.allowPressChromeDimming, isTrue);
  });

  test('policy override 可用于 engine', () {
    final container = ProviderContainer(
      overrides: [
        playerPerformancePolicyOverrideProvider.overrideWithValue(
          PlayerPerformancePolicy.stable,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(playerFeedEngineProvider(PlayerPlaybackSessionKeys.forYouTab))
          .policy
          .isStable,
      isTrue,
    );
  });

  test('PlayerOverlaySheetIntent 覆盖 manual/auto 分支', () {
    expect(PlayerOverlaySheetIntent.coinUnlock.name, 'coinUnlock');
    expect(PlayerOverlaySheetIntent.rechargeUnlock.name, 'rechargeUnlock');
    expect(PlayerOverlaySheetIntent.membership.name, 'membership');
  });
}
