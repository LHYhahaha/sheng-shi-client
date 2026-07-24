import '../domain/reward_coins_check_in_status.dart';
import '../domain/reward_coins_check_in_claim_result.dart';
import '../domain/reward_coins_repository.dart';
import 'remote/reward_coins_remote_data_source.dart';

class RemoteRewardCoinsRepository implements RewardCoinsRepository {
  const RemoteRewardCoinsRepository({
    required RewardCoinsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final RewardCoinsRemoteDataSource _remoteDataSource;

  @override
  Future<RewardCoinsCheckInStatus> getCheckInStatus() async {
    final dto = await _remoteDataSource.getCheckInStatus();
    return dto.toDomain();
  }

  @override
  Future<RewardCoinsCheckInClaimResult> claimCheckIn() async {
    final dto = await _remoteDataSource.claimCheckIn();
    return dto.toDomain();
  }
}
