import 'member_point_claim_result.dart';
import 'member_point_daily_detail.dart';
import 'member_point_details.dart';
import 'member_point_exchange_options.dart';
import 'member_point_exchange_result.dart';

abstract interface class MemberPointsRepository {
  Future<MemberPointDailyDetail> getDailyDetail();

  Future<MemberPointClaimResult> claimReward({required String taskKey});

  Future<MemberPointExchangeOptions> getExchangeOptions();

  Future<MemberPointExchangeResult> exchange({required int tierId});

  Future<MemberPointDetailsPage> getPointDetails({
    required int page,
    required int pageSize,
  });
}
