import 'reward_coins_check_in_status.dart';
import 'reward_coins_check_in_claim_result.dart';
import 'reward_coin_remaining.dart';
import 'reward_task.dart';

abstract interface class RewardCoinsRepository {
  Future<RewardCoinsCheckInStatus> getCheckInStatus();
  Future<RewardCoinsCheckInClaimResult> claimCheckIn();
  Future<RewardCoinsCheckInClaimResult> claimTask({required String taskKey});
  Future<RewardCoinRemaining> getRemainingCoin();
  Future<List<RewardTask>> getTasks({required int rewardType});

  Future<void> reportTaskAction({required String actionKey});
}
