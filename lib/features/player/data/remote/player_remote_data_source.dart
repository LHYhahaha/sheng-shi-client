import '../../../../core/network/api_client.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_episode_dto.dart';
import '../dto/player_feed_page_dto.dart';

/// Player 内容/Feed 远程数据源骨架。
///
/// 只负责 API 调用和 DTO 解析，不返回 domain model，也不创建播放器 session。
class PlayerRemoteDataSource {
  const PlayerRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PlayerContentDto> getDramaDetail({required String dramaId}) {
    return _apiClient.get<PlayerContentDto>(
      '/dramas/$dramaId',
      decoder: (data) {
        if (data is Map<String, Object?>) {
          return PlayerContentDto.fromJson(data);
        }
        return const PlayerContentDto(
          dramaId: '',
          title: '',
          description: null,
          posterUrl: null,
          backgroundUrl: null,
          totalEpisodes: 0,
          tags: [],
          viewCount: null,
          viewCountLabel: null,
          likeCountLabel: null,
          episodes: [],
        );
      },
    );
  }

  Future<List<PlayerEpisodeDto>> listEpisodes({required String dramaId}) {
    return _apiClient.get<List<PlayerEpisodeDto>>(
      '/dramas/$dramaId/episodes',
      decoder: (data) {
        final items = _extractItems(data);
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
      decoder: (data) {
        if (data is Map<String, Object?>) {
          return PlayerFeedPageDto.fromJson(data);
        }
        return const PlayerFeedPageDto(items: [], nextPageToken: null);
      },
    );
  }

  List<Object?> _extractItems(Object? data) {
    if (data is List) return data;
    if (data is Map<String, Object?> && data['items'] is List) {
      return data['items']! as List<Object?>;
    }
    return const <Object?>[];
  }
}
