import '../../../../core/network/api_client.dart';
import '../../../search/data/dto/search_ranking_response_dto.dart';
import '../dto/home_response_dto.dart';
import '../dto/vip_only_dramas_response_dto.dart';

class HomeRemoteDataSource {
  const HomeRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<SearchRankingResponseDto> getHotSearchKeywords() {
    return _apiClient.get<SearchRankingResponseDto>(
      '/api/home/search/hot',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        if (data is! Map) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }
        return SearchRankingResponseDto.fromJson(
          Map<String, Object?>.from(data),
        );
      },
    );
  }

  Future<HomeResponseDto> getHomeData({
    int? page,
    int pageSize = 20,
    int? tabId,
  }) async {
    final queryParameters = <String, Object?>{};
    if (page != null) {
      queryParameters['page'] = page;
    }
    if (tabId != null) {
      queryParameters['tab_id'] = tabId.toString();
    }
    if (queryParameters.isNotEmpty) {
      queryParameters['page_size'] = pageSize;
    }

    return _apiClient.get<HomeResponseDto>(
      '/api/home',
      authPolicy: ApiAuthPolicy.required,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
      decoder: (data) {
        if (data is! Map) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }

        final dto = HomeResponseDto.fromJson(Map<String, Object?>.from(data));

        return dto;
      },
    );
  }

  Future<VipOnlyDramasResponseDto> getVipOnlyDramas() {
    return _apiClient.get<VipOnlyDramasResponseDto>(
      '/api/home/vip-only',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        if (data is! Map) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }
        return VipOnlyDramasResponseDto.fromJson(
          Map<String, Object?>.from(data),
        );
      },
    );
  }
}
