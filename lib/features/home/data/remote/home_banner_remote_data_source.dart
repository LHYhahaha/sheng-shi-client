import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/home_banner_response_dto.dart';

class HomeBannerRemoteDataSource {
  const HomeBannerRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<HomeBannerResponseDto> fetchBanners() {
    return _apiClient.get<HomeBannerResponseDto>(
      '/api/config/home-banner',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => HomeBannerResponseDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'HomeBannerResponseDto'),
      ),
    );
  }
}
