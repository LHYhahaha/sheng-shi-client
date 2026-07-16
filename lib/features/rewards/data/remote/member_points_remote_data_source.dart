import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/member_point_claim_result_dto.dart';
import '../dto/member_point_daily_detail_dto.dart';
import '../dto/member_point_details_dto.dart';
import '../dto/member_point_exchange_options_dto.dart';
import '../dto/member_point_exchange_result_dto.dart';

class MemberPointsRemoteDataSource {
  const MemberPointsRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MemberPointDailyDetailDto> getDailyDetail() {
    return _apiClient.get<MemberPointDailyDetailDto>(
      '/api/activity/member-point/daily-detail',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MemberPointDailyDetailDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'MemberPointDailyDetailDto'),
      ),
    );
  }

  Future<MemberPointClaimResultDto> claimReward({required String taskKey}) {
    return _apiClient.post<MemberPointClaimResultDto>(
      '/api/activity/member-point/reward/claim',
      data: {'taskKey': taskKey},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MemberPointClaimResultDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'MemberPointClaimResultDto'),
      ),
    );
  }

  Future<MemberPointExchangeOptionsDto> getExchangeOptions() {
    return _apiClient.get<MemberPointExchangeOptionsDto>(
      '/api/activity/member-point/exchange-options',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MemberPointExchangeOptionsDto.fromJson(
        JsonFieldParser.requireMap(
          data,
          dtoName: 'MemberPointExchangeOptionsDto',
        ),
      ),
    );
  }

  Future<MemberPointExchangeResultDto> exchange({required int tierId}) {
    return _apiClient.post<MemberPointExchangeResultDto>(
      '/api/activity/member-point/exchange',
      data: {'tierId': tierId},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MemberPointExchangeResultDto.fromJson(
        JsonFieldParser.requireMap(
          data,
          dtoName: 'MemberPointExchangeResultDto',
        ),
      ),
    );
  }

  Future<MemberPointDetailsPageDto> getPointDetails({
    required int page,
    required int pageSize,
  }) {
    return _apiClient.get<MemberPointDetailsPageDto>(
      '/api/activity/member-point/details',
      queryParameters: <String, Object?>{'page': page, 'page_size': pageSize},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => MemberPointDetailsPageDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'MemberPointDetailsPageDto'),
      ),
    );
  }
}
