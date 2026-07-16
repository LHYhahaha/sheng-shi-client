import '../domain/member_point_claim_result.dart';
import '../domain/member_point_daily_detail.dart';
import '../domain/member_point_details.dart';
import '../domain/member_point_exchange_options.dart';
import '../domain/member_point_exchange_result.dart';
import '../domain/member_points_repository.dart';
import 'remote/member_points_remote_data_source.dart';

class RemoteMemberPointsRepository implements MemberPointsRepository {
  const RemoteMemberPointsRepository({
    required MemberPointsRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final MemberPointsRemoteDataSource _remoteDataSource;

  @override
  Future<MemberPointDailyDetail> getDailyDetail() async {
    final dto = await _remoteDataSource.getDailyDetail();
    return dto.toDomain();
  }

  @override
  Future<MemberPointClaimResult> claimReward({required String taskKey}) async {
    final dto = await _remoteDataSource.claimReward(taskKey: taskKey);
    return dto.toDomain();
  }

  @override
  Future<MemberPointExchangeOptions> getExchangeOptions() async {
    final dto = await _remoteDataSource.getExchangeOptions();
    return dto.toDomain();
  }

  @override
  Future<MemberPointExchangeResult> exchange({required int tierId}) async {
    final dto = await _remoteDataSource.exchange(tierId: tierId);
    return dto.toDomain();
  }

  @override
  Future<MemberPointDetailsPage> getPointDetails({
    required int page,
    required int pageSize,
  }) async {
    final dto = await _remoteDataSource.getPointDetails(
      page: page,
      pageSize: pageSize,
    );
    return dto.toDomain();
  }
}
