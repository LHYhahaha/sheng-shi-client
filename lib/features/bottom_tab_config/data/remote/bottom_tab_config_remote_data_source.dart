import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/bottom_tab_response_dto.dart';

/// 动态底部 Tab 配置的远端入口。
///
/// 目前仅完成 API 契约接入，尚未改变现有静态 Tab 的展示或路由行为。
class BottomTabConfigRemoteDataSource {
  const BottomTabConfigRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<BottomTabResponseDto> fetchBottomTabs() {
    return _apiClient.get<BottomTabResponseDto>(
      '/api/config/bottom-tabs',
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => BottomTabResponseDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'BottomTabResponseDto'),
      ),
    );
  }
}
