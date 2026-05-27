import '../../../../core/network/api_client.dart';
import '../dto/home_response_dto.dart';

/// 首页远程数据源。
///
/// 负责调用 /api/home 接口获取首页数据，需要登录后的 token。
class HomeRemoteDataSource {
  const HomeRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 获取首页数据。
  ///
  /// 需要在登录后携带 token 才能请求通。
  Future<HomeResponseDto> getHomeData() {
    print('[HomeRemoteDataSource] getHomeData request:');
    print('[HomeRemoteDataSource]   URL: GET /api/home');
    
    return _apiClient.get<HomeResponseDto>(
      '/api/home',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        print('[HomeRemoteDataSource] getHomeData response data: $data');
        
        if (data is! Map<String, Object?>) {
          throw Exception('Expected Map response, got ${data.runtimeType}');
        }
        
        final dto = HomeResponseDto.fromJson(data);
        print('[HomeRemoteDataSource] getHomeData parsed:');
        print('[HomeRemoteDataSource]   id: ${dto.id}');
        print('[HomeRemoteDataSource]   name: ${dto.name}');
        print('[HomeRemoteDataSource]   tabs count: ${dto.tabs.length}');
        
        return dto;
      },
    );
  }
}
