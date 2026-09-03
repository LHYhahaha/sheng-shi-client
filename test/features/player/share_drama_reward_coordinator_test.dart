import 'package:drama_client/features/player/application/share_drama_reward_coordinator.dart';
import 'package:drama_client/features/player/data/dto/share_drama_status_dto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'claims Facebook share reward only after returning from background',
    () async {
      final claims = <String>[];
      final coordinator = ShareDramaRewardCoordinator(
        claimReward: (taskKey) async => claims.add(taskKey),
      );

      coordinator.register(
        taskKey: 'coin.share_drama',
        channel: ShareDramaRewardChannel.facebook,
      );

      expect(coordinator.onLifecycleChanged(AppLifecycleState.resumed), isNull);
      expect(coordinator.onLifecycleChanged(AppLifecycleState.paused), isNull);
      expect(
        coordinator.onLifecycleChanged(AppLifecycleState.resumed),
        ShareDramaRewardChannel.facebook,
      );
      await Future<void>.delayed(Duration.zero);
      expect(claims, ['coin.share_drama']);
      expect(coordinator.hasPending, isFalse);
    },
  );

  test('refreshes the share status after claiming a reward', () async {
    var statusRequestCount = 0;
    final coordinator = ShareDramaRewardCoordinator(
      claimReward: (_) async {},
      fetchStatus: () async {
        statusRequestCount++;
        return const ShareDramaStatusDto(
          claimed: true,
          completed: true,
          info: ShareDramaTaskInfoDto(
            configKey: 'coin.share_drama',
            minValue: 12,
          ),
        );
      },
    );

    coordinator.register(
      taskKey: 'coin.share_drama',
      channel: ShareDramaRewardChannel.copyLink,
    );
    coordinator.onLifecycleChanged(AppLifecycleState.paused);
    coordinator.onLifecycleChanged(AppLifecycleState.resumed);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(statusRequestCount, 1);
    expect((await coordinator.loadStatus())?.claimed, isTrue);
  });

  test(
    'reports the action before claiming a completed but unclaimed task',
    () async {
      final events = <String>[];
      final coordinator = ShareDramaRewardCoordinator(
        claimReward: (_) async => events.add('claim'),
        reportShareAction: () async => events.add('report'),
      );

      coordinator.register(
        taskKey: 'coin.share_drama',
        channel: ShareDramaRewardChannel.copyLink,
      );
      coordinator.onLifecycleChanged(AppLifecycleState.paused);
      coordinator.onLifecycleChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['report', 'claim']);
    },
  );

  test('latest copy replaces the previous pending reward', () async {
    final claims = <String>[];
    final coordinator = ShareDramaRewardCoordinator(
      claimReward: (taskKey) async => claims.add(taskKey),
    );

    coordinator.register(
      taskKey: 'old-task',
      channel: ShareDramaRewardChannel.copyLink,
    );
    coordinator.register(
      taskKey: 'new-task',
      channel: ShareDramaRewardChannel.copyLink,
    );
    coordinator.onLifecycleChanged(AppLifecycleState.hidden);
    expect(
      coordinator.onLifecycleChanged(AppLifecycleState.resumed),
      ShareDramaRewardChannel.copyLink,
    );
    await Future<void>.delayed(Duration.zero);
    expect(claims, ['new-task']);
  });

  test(
    'does not claim a reward after the five-minute validity window',
    () async {
      var now = DateTime(2026, 8, 31, 12);
      var claimCount = 0;
      final coordinator = ShareDramaRewardCoordinator(
        claimReward: (_) async => claimCount++,
        clock: () => now,
      );

      coordinator.register(
        taskKey: 'coin.share_drama',
        channel: ShareDramaRewardChannel.copyLink,
      );
      coordinator.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 5));

      expect(coordinator.onLifecycleChanged(AppLifecycleState.resumed), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(claimCount, 0);
      expect(coordinator.hasPending, isFalse);
    },
  );
}
