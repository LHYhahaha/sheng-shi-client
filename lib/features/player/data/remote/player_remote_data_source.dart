import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_feed_page_dto.dart';

/// Player 内容/Feed 远程数据源。
class PlayerRemoteDataSource {
  const PlayerRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 获取短剧详情（包含所有集数和字幕信息）。
  Future<PlayerContentDto> fetchDramaDetail({required int dramaId}) {
    return _apiClient.get<PlayerContentDto>(
      '/api/home/detail',
      queryParameters: <String, Object?>{'id': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => PlayerContentDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayerContentDto'),
      ),
    );
  }

  Future<PlayerFeedPageDto> listForYouFeed({String? pageToken}) {
    return _apiClient.get<PlayerFeedPageDto>(
      '/feed/for-you',
      queryParameters: <String, Object?>{'pageToken': pageToken}
        ..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => PlayerFeedPageDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayerFeedPageDto'),
      ),
    );
  }
}
