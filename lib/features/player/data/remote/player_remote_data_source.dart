import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_episode_dto.dart';
import '../dto/player_feed_page_dto.dart';

/// Player 内容/Feed 远程数据源骨架。
class PlayerRemoteDataSource {
  const PlayerRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PlayerContentDto> getDramaDetail({required String dramaId}) {
    return _apiClient.get<PlayerContentDto>(
      '/dramas/$dramaId',
      decoder: (data) => PlayerContentDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayerContentDto'),
      ),
    );
  }

  Future<List<PlayerEpisodeDto>> listEpisodes({required String dramaId}) {
    return _apiClient.get<List<PlayerEpisodeDto>>(
      '/dramas/$dramaId/episodes',
      decoder: (data) {
        final items = _extractItems(data, dtoName: 'PlayerEpisodeDto');
        return items
            .whereType<Map<String, Object?>>()
            .map(PlayerEpisodeDto.fromJson)
            .toList(growable: false);
      },
    );
  }

  Future<PlayerFeedPageDto> listForYouFeed({String? pageToken}) {
    return _apiClient.get<PlayerFeedPageDto>(
      '/feed/for-you',
      queryParameters: <String, Object?>{'pageToken': pageToken}
        ..removeWhere((_, value) => value == null),
      decoder: (data) => PlayerFeedPageDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayerFeedPageDto'),
      ),
    );
  }

  List<Object?> _extractItems(Object? data, {required String dtoName}) {
    if (data is List) return data;
    if (data is Map<String, Object?> && data['items'] is List) {
      return data['items']! as List<Object?>;
    }
    throw ApiMappingException(
      dtoName: dtoName,
      field: 'items',
      reason: 'expected array payload',
    );
  }
}
