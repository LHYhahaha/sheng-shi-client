import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client_provider.dart';
import '../domain/reward_coins_repository.dart';
import 'remote/reward_coins_remote_data_source.dart';
import 'remote_reward_coins_repository.dart';

final rewardCoinsRepositoryProvider = Provider<RewardCoinsRepository>((ref) {
  return RemoteRewardCoinsRepository(
    remoteDataSource: RewardCoinsRemoteDataSource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});
