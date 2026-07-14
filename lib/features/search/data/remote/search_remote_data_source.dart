import '../../../../core/network/api_client.dart';
import '../dto/search_ranking_response_dto.dart';
import '../dto/search_results_response_dto.dart';

class SearchRemoteDataSource {
  const SearchRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<SearchRankingResponseDto> getHotSearches() {
    return _getRanking('/api/home/search/hot');
  }

  Future<SearchRankingResponseDto> getHotPlays() {
    return _getRanking('/api/home/play/hot');
  }

  Future<SearchRankingResponseDto> getNewOnline() {
    return _getRanking('/api/home/online/new');
  }

  Future<void> reportSearchResultClick({required String dramaId}) {
    return _apiClient.post<void>(
      '/api/home/search/stat',
      data: <String, Object?>{'drama_id': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );
  }

  Future<SearchResultsResponseDto> search({
    required String keyword,
    required String page,
    required String pageSize,
    String? sortType,
  }) async {
    final queryParameters = <String, Object?>{
      'keyword': keyword,
      'page': page,
      'page_size': pageSize,
      'sort_type': ?sortType,
    };

    return _apiClient.get<SearchResultsResponseDto>(
      '/api/home/search',
      queryParameters: queryParameters,
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        if (data is! Map) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }
        return SearchResultsResponseDto.fromJson(
          Map<String, Object?>.from(data),
        );
      },
    );
  }

  Future<SearchRankingResponseDto> _getRanking(String path) async {
    return _apiClient.get<SearchRankingResponseDto>(
      path,
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
}
