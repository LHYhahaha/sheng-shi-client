import 'package:drama_client/features/rewards/application/reward_coins_controller.dart';
import 'package:drama_client/features/rewards/data/reward_coins_repository_provider.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_check_in_claim_result.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_check_in_status.dart';
import 'package:drama_client/features/rewards/domain/reward_coins_repository.dart';
import 'package:drama_client/features/rewards/domain/reward_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unchanged check-in status refreshes without updating page state',
    () async {
      final repository = _FakeRewardCoinsRepository();
      final container = ProviderContainer(
        overrides: [
          rewardCoinsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final states = <RewardCoinsState>[];
      final subscription = container.listen<RewardCoinsState>(
        rewardCoinsControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final controller = container.read(rewardCoinsControllerProvider.notifier);
      await controller.loadCheckInStatus();
      final updatesAfterInitialLoad = states.length;
      await controller.loadCheckInStatus();

      expect(repository.checkInRequestCount, 2);
      expect(states, hasLength(updatesAfterInitialLoad));
      expect(states.last.isCheckInLoading, isFalse);
    },
  );
}

class _FakeRewardCoinsRepository implements RewardCoinsRepository {
  int checkInRequestCount = 0;

  @override
  Future<RewardCoinsCheckInStatus> getCheckInStatus() async {
    checkInRequestCount++;
    return const RewardCoinsCheckInStatus(
      checkedDays: 0,
      checkedToday: false,
      currentDay: 1,
      days: [
        RewardCoinsCheckInDay(
          checked: false,
          claimable: true,
          current: true,
          day: 1,
          rewardCoin: '5',
        ),
      ],
    );
  }

  @override
  Future<RewardCoinsCheckInClaimResult> claimCheckIn() =>
      throw UnimplementedError();

  @override
  Future<RewardCoinsCheckInClaimResult> claimTask({required String taskKey}) =>
      throw UnimplementedError();

  @override
  Future<List<RewardTask>> getTasks({required int rewardType}) =>
      throw UnimplementedError();

  @override
  Future<void> reportTaskAction({required String actionKey}) =>
      throw UnimplementedError();
}
