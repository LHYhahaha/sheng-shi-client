import 'package:dio/dio.dart';

import '../../../../core/channel/channel_config_service.dart';
import '../../../../core/network/api_client.dart';
import '../dto/search_ranking_response_dto.dart';
import '../dto/search_results_response_dto.dart';

class SearchRemoteDataSource {
  const SearchRemoteDataSource({
    required ApiClient apiClient,
    required ChannelConfigService channelConfigService,
  }) : _apiClient = apiClient,
       _channelConfigService = channelConfigService;

  final ApiClient _apiClient;
  final ChannelConfigService _channelConfigService;

  Future<SearchRankingResponseDto> getHotSearches() {
    return _getRanking('/api/home/search/hot');
  }

  Future<SearchRankingResponseDto> getHotPlays() {
    return _getRanking('/api/home/play/hot');
  }

  Future<SearchRankingResponseDto> getNewOnline() {
    return _getRanking('/api/home/online/new');
  }

  Future<SearchResultsResponseDto> search({
    required String keyword,
    required String page,
    required String pageSize,
    String? sortType,
  }) async {
    final channelConfig = await _channelConfigService.getChannelConfig();
    final options = channelConfig.hasConfig
        ? Options(
            headers: {
              'Content-Type': 'application/json',
              ...channelConfig.toHeaders(),
            },
          )
        : null;
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
      options: options,
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
    final channelConfig = await _channelConfigService.getChannelConfig();
    final options = channelConfig.hasConfig
        ? Options(
            headers: {
              'Content-Type': 'application/json',
              ...channelConfig.toHeaders(),
            },
          )
        : null;

    return _apiClient.get<SearchRankingResponseDto>(
      path,
      authPolicy: ApiAuthPolicy.required,
      options: options,
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
