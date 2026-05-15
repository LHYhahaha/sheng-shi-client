import '../../../../core/network/api_client.dart';
import '../dto/profile_summary_dto.dart';

class ProfileRemoteDataSource {
  const ProfileRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ProfileSummaryDto> getProfile() {
    return _apiClient.get<ProfileSummaryDto>(
      '/profile',
      authPolicy: ApiAuthPolicy.required,
      decoder: ProfileSummaryDto.fromJson,
    );
  }
}
