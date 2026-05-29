import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../../../my_list/data/dto/favorite_mutation_dto.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_feed_page_dto.dart';
import '../dto/short_follow_check_dto.dart';
import '../dto/watch_progress_report_dto.dart';

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

  /// 点赞短剧。
  Future<void> followShort({required int dramaId}) {
    return _apiClient.post<void>(
      '/api/user/short/follow',
      data: {'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  /// 取消点赞短剧。
  Future<void> unfollowShort({required int dramaId}) {
    return _apiClient.post<void>(
      '/api/user/short/unfollow',
      data: {'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: FavoriteMutationDto.fromJson,
    );
  }

  /// 检查短剧点赞状态。
  Future<bool> checkShortFollowStatus({required int dramaId}) {
    return _apiClient.get<ShortFollowCheckDto>(
      '/api/user/short/follow/check',
      queryParameters: <String, Object?>{'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => ShortFollowCheckDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'ShortFollowCheckDto'),
      ),
    ).then((dto) => dto.followed);
  }

  /// 上报观看进度。
  Future<void> reportWatchProgress({
    required bool autoUnlockNext,
    required int dramaId,
    required int durationSecond,
    int? episodeId,
    required int episodeNo,
    required int eventType,
    required int watchSecond,
  }) {
    final dto = WatchProgressReportDto(
      autoUnlockNext: autoUnlockNext,
      dramaId: dramaId,
      durationSecond: durationSecond,
      episodeId: episodeId,
      episodeNo: episodeNo,
      eventType: eventType,
      watchSecond: watchSecond,
    );
    return _apiClient.post<void>(
      '/api/user/watch/progress/report',
      data: dto.toJson(),
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) => null,
    );
  }
}
