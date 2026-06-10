import 'package:dio/dio.dart';

import '../../../../core/channel/channel_config_service.dart';
import '../../../../core/network/api_client.dart';
import '../dto/home_response_dto.dart';

/// 首页远程数据源。
///
/// 负责调用 /api/home 接口获取首页数据，需要登录后的 token。
class HomeRemoteDataSource {
  const HomeRemoteDataSource({
    required ApiClient apiClient,
    required ChannelConfigService channelConfigService,
  }) : _apiClient = apiClient,
       _channelConfigService = channelConfigService;

  final ApiClient _apiClient;
  final ChannelConfigService _channelConfigService;

  /// 获取首页数据。
  ///
  /// 需要在登录后携带 token 才能请求通。
  /// 此接口会自动携带渠道配置头（如果有配置的话）。
  Future<HomeResponseDto> getHomeData() async {
    print('[HomeRemoteDataSource] GET /api/home');

    // 获取渠道配置（ChannelConfigService 内部有缓存，不会重复调用 MethodChannel）
    final channelConfig = await _channelConfigService.getChannelConfig();

    // 只有在有渠道配置时才添加自定义头
    final options = channelConfig.hasConfig
        ? Options(
            headers: {
              'Content-Type': 'application/json',
              ...channelConfig.toHeaders(),
            },
          )
        : null;

    if (channelConfig.hasConfig) {
      print('[HomeRemoteDataSource]   携带渠道头: ${channelConfig.toHeaders()}');
    }

    return _apiClient.get<HomeResponseDto>(
      '/api/home',
      authPolicy: ApiAuthPolicy.required,
      options: options,
      decoder: (data) {
        if (data is! Map) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }

        final dto = HomeResponseDto.fromJson(Map<String, Object?>.from(data));
        print('[HomeRemoteDataSource]   解析完成: ${dto.tabs.length} 个标签');

        return dto;
      },
    );
  }
}
