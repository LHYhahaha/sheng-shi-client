import '../../../../core/network/api_client.dart';
import '../dto/profile_summary_dto.dart';
import '../dto/wallet_dto.dart';

class ProfileRemoteDataSource {
  const ProfileRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ProfileSummaryDto> getProfile() {
    return _apiClient.get<ProfileSummaryDto>(
      '/api/user/get',
      authPolicy: ApiAuthPolicy.required,
      decoder: ProfileSummaryDto.fromJson,
    );
  }

  Future<WalletDto> getWallet(int userId) {
    return _apiClient.get<WalletDto>(
      '/api/payment/wallet',
      authPolicy: ApiAuthPolicy.required,
      decoder: WalletDto.fromJson,
    );
  }
}
