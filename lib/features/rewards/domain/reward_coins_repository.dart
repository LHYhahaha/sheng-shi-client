import 'reward_coins_check_in_status.dart';
import 'reward_coins_check_in_claim_result.dart';

abstract interface class RewardCoinsRepository {
  Future<RewardCoinsCheckInStatus> getCheckInStatus();
  Future<RewardCoinsCheckInClaimResult> claimCheckIn();
}
