import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../../rewards/data/remote/reward_coins_remote_data_source.dart';
import '../../rewards/domain/reward_coins_check_in_claim_result.dart';
import '../../rewards/domain/reward_task.dart';
import '../domain/watch_reward_repository.dart';

final watchRewardRepositoryProvider = Provider<WatchRewardRepository>((ref) {
  return RemoteWatchRewardRepository(
    RewardCoinsRemoteDataSource(apiClient: ref.watch(apiClientProvider)),
  );
});

class RemoteWatchRewardRepository implements WatchRewardRepository {
  const RemoteWatchRewardRepository(this.remote);
  final RewardCoinsRemoteDataSource remote;

  @override
  Future<List<RewardTask>> getWatchTasks() async =>
      (await remote.getWatchTasks()).toDomain();

  @override
  Future<RewardCoinsCheckInClaimResult> claim(String taskKey) async =>
      (await remote.claimTask(taskKey: taskKey)).toDomain();
}
