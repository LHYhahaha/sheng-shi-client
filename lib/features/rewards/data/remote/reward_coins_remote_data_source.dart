import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/reward_coins_check_in_status_dto.dart';

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
}
