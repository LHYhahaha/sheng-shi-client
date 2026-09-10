import 'dart:async';

import 'package:drama_client/core/auth/user_info_store.dart';
import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/player/application/player_watch_reward_coordinator_provider.dart';
import 'package:drama_client/features/player/data/shared_preferences_watch_reward_attempt_store.dart';
import 'package:drama_client/features/player/data/watch_reward_repository_provider.dart';
import 'package:drama_client/features/player/domain/watch_reward_repository.dart';
import 'package:drama_client/features/rewards/application/reward_coins_controller.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_check_in_claim_result.dart';
import 'package:drama_client/features/rewards/domain/reward_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _User extends UserInfoStore {
  @override
  UserInfoSnapshot build() => const UserInfoSnapshot(userId: 'a');
  void change() => state = const UserInfoSnapshot(userId: 'b');
}

class _Entitlement extends EntitlementController {
  int refreshes = 0;
  @override
  Future<bool> refreshFromServer() async {
    refreshes++;
    return true;
  }
}

class _Coins extends RewardCoinsController {
  int taskRefreshes = 0;
  int balanceRefreshes = 0;
  @override
  Future<void> loadTasks() async {
    taskRefreshes++;
  }

  @override
  Future<void> loadRemainingCoin() async {
    balanceRefreshes++;
  }
}

class _Attempts implements WatchRewardAttemptStore {
  @override
  Future<Map<String, WatchRewardAttempt>> read(
    String userId,
    String dayKey,
  ) async => {};
  @override
  Future<void> write(
    String userId,
    String dayKey,
    Map<String, WatchRewardAttempt> attempts,
  ) async {}
}

class _Repository implements WatchRewardRepository {
  final pending = Completer<RewardCoinsCheckInClaimResult>();
  final started = Completer<void>();
  @override
  Future<List<RewardTask>> getWatchTasks() async => [
    const RewardTask(
      claimed: false,
      completed: false,
      conditionText: '',
      cycleType: 'TASK_CYCLE_TYPE_DAILY',
      displayName: 'watch',
      progressValue: 0,
      rewardMax: 1,
      rewardMin: 1,
      rewardType: 'REWARD_TYPE_BONUS_COIN',
      targetValue: 300,
      taskKey: 'watch',
    ),
  ];
  @override
  Future<RewardCoinsCheckInClaimResult> claim(String taskKey) {
    started.complete();
    return pending.future;
  }
}

void main() {
  for (final switchUser in [false, true]) {
    test(
      'hidden-page grant refresh is account scoped: switchUser=$switchUser',
      () async {
        final repository = _Repository();
        final container = ProviderContainer(
          overrides: [
            userInfoStoreProvider.overrideWith(_User.new),
            entitlementControllerProvider.overrideWith(_Entitlement.new),
            rewardCoinsControllerProvider.overrideWith(_Coins.new),
            watchRewardRepositoryProvider.overrideWithValue(repository),
            watchRewardAttemptStoreProvider.overrideWithValue(_Attempts()),
          ],
        );
        addTearDown(container.dispose);
        final coins =
            container.read(rewardCoinsControllerProvider.notifier) as _Coins;
        final entitlement =
            container.read(entitlementControllerProvider.notifier)
                as _Entitlement;
        final coordinator = container.read(
          playerWatchRewardCoordinatorProvider,
        );
        var toasts = 0;
        coordinator.update(
          owner: 'player',
          userId: 'a',
          dayKey: '2026-09-10',
          seconds: 300,
          visible: true,
          isCurrent: () => true,
          onSuccess: (_) => toasts++,
        );
        await repository.started.future;
        coordinator.leave('player');
        if (switchUser) {
          (container.read(userInfoStoreProvider.notifier) as _User).change();
        }
        repository.pending.complete(
          const RewardCoinsCheckInClaimResult(
            balance: 20,
            claimNo: 'c',
            grantedAt: '',
            rewardAmount: 1,
            rewardType: 'REWARD_TYPE_BONUS_COIN',
            status: 'CLAIM_STATUS_SUCCESS',
          ),
        );
        await coordinator.settled;
        await Future<void>.delayed(Duration.zero);
        expect(toasts, 0);
        expect(entitlement.refreshes, switchUser ? 0 : 1);
        expect(coins.taskRefreshes, switchUser ? 0 : 1);
        expect(coins.balanceRefreshes, switchUser ? 0 : 1);
      },
    );
  }
}
