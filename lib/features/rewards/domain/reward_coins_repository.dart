import 'reward_coins_check_in_status.dart';

abstract interface class RewardCoinsRepository {
  Future<RewardCoinsCheckInStatus> getCheckInStatus();
}
