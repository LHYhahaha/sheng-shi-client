import '../../rewards/domain/reward_coins_check_in_claim_result.dart';
import '../../rewards/domain/reward_task.dart';

/// Both reward types share the activity task/claim response contracts.
abstract interface class WatchRewardRepository {
  Future<List<RewardTask>> getWatchTasks();
  Future<RewardCoinsCheckInClaimResult> claim(String taskKey);
}

class WatchRewardAttempt {
  const WatchRewardAttempt({
    this.count = 0,
    this.lastAttemptSeconds = 0,
    this.succeeded = false,
  });
  final int count;
  final int lastAttemptSeconds;
  final bool succeeded;
}

abstract interface class WatchRewardAttemptStore {
  Future<Map<String, WatchRewardAttempt>> read(String userId, String dayKey);
  Future<void> write(
    String userId,
    String dayKey,
    Map<String, WatchRewardAttempt> attempts,
  );
}
