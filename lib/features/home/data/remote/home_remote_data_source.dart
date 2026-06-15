import 'package:dio/dio.dart';

import '../../../../core/channel/channel_config_service.dart';
import '../../../../core/network/api_client.dart';
import '../dto/home_response_dto.dart';

class HomeRemoteDataSource {
  const HomeRemoteDataSource({
    required ApiClient apiClient,
    required ChannelConfigService channelConfigService,
  }) : _apiClient = apiClient,
       _channelConfigService = channelConfigService;

  final ApiClient _apiClient;
  final ChannelConfigService _channelConfigService;

  Future<HomeResponseDto> getHomeData({
    int? page,
    int pageSize = 20,
    int? tabId,
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
      options: options,
      decoder: (data) {
        if (data is! Map) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }

        final dto = HomeResponseDto.fromJson(Map<String, Object?>.from(data));

        return dto;
      },
    );
  }
}
