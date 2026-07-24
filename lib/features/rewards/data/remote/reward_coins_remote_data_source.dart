import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/reward_coins_check_in_status_dto.dart';
import '../dto/reward_coins_check_in_claim_result_dto.dart';
import '../dto/reward_task_list_dto.dart';

class RewardCoinsRemoteDataSource {
  const RewardCoinsRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<RewardCoinsCheckInStatusDto> getCheckInStatus() {
    return _apiClient.get<RewardCoinsCheckInStatusDto>(
      '/api/activity/checkin/status',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => RewardCoinsCheckInStatusDto.fromJson(
        JsonFieldParser.requireMap(
          data,
          dtoName: 'RewardCoinsCheckInStatusDto',
        ),
      ),
    );
  }

  Future<RewardCoinsCheckInClaimResultDto> claimCheckIn() {
    return _apiClient.post<RewardCoinsCheckInClaimResultDto>(
      '/api/activity/checkin',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => RewardCoinsCheckInClaimResultDto.fromJson(
        JsonFieldParser.requireMap(
          data,
          dtoName: 'RewardCoinsCheckInClaimResultDto',
        ),
      ),
    );
  }

  Future<RewardCoinsCheckInClaimResultDto> claimTask({
    required String taskKey,
  }) {
    return _apiClient.post<RewardCoinsCheckInClaimResultDto>(
      '/api/activity/task/reward/claim',
      data: {'taskKey': taskKey},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => RewardCoinsCheckInClaimResultDto.fromJson(
        JsonFieldParser.requireMap(
          data,
          dtoName: 'RewardCoinsCheckInClaimResultDto',
        ),
      ),
    );
  }

  Future<RewardTaskListDto> getTasks({required int rewardType}) {
    return _apiClient.get<RewardTaskListDto>(
      '/api/activity/task/list',
      queryParameters: {'rewardType': rewardType},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => RewardTaskListDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'RewardTaskListDto'),
      ),
    );
  }

  Future<void> reportTaskAction({required String actionKey}) {
    return _apiClient.post<void>(
      '/api/activity/task/action/report',
      data: {'actionKey': actionKey},
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );
  }
}
