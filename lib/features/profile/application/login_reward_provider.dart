import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../rewards/data/reward_coins_repository_provider.dart';
import '../../rewards/domain/reward_task.dart';

final loginRewardCoinsProvider = FutureProvider.autoDispose<int?>((ref) async {
  final token = ref.watch(
    authTokenStoreProvider.select((state) => state.accessToken),
  );
  if (token == null || token.isEmpty) return null;
  final tasks = await ref
      .watch(rewardCoinsRepositoryProvider)
      .getTasks(rewardType: 1, businessType: 1);
  return loginRewardCoinsForTasks(tasks);
});

int? loginRewardCoinsForTasks(List<RewardTask> tasks) {
  final task = tasks
      .where((task) => task.taskKey == 'coin.bind_account')
      .firstOrNull;
  if (task == null || task.completed || task.claimed || task.rewardMin <= 0) {
    return null;
  }
  return task.rewardMin;
}
