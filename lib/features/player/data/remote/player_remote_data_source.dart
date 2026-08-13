import 'package:drama_client/features/store/data/dto/store_recharge_data_dto.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/json_field_parser.dart';
import '../../../my_list/data/dto/favorite_mutation_dto.dart';
import '../dto/player_content_dto.dart';
import '../dto/player_episode_unlock_dto.dart';
import '../dto/player_feed_page_dto.dart';
import '../dto/player_recommendation_dto.dart';
import '../dto/short_follow_check_dto.dart';
import '../dto/watch_progress_dto.dart';
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

  /// 获取充值页面数据
  ///
  /// 对应后端 API：GET /api/payment/recharge/page
  Future<StoreRechargeDataDto> fetchRechargePage() {
    return _apiClient.get<StoreRechargeDataDto>(
      '/api/payment/recharge/page',
      authPolicy: ApiAuthPolicy.required,
      decoder: StoreRechargeDataDto.fromJson,
    );
  }

  /// 获取推荐列表。
  Future<List<PlayerRecommendationDto>> fetchRecommendations({
    required int dramaId,
    required List<int> tagIds,
  }) {
    return _apiClient.post<List<PlayerRecommendationDto>>(
      '/api/home/tags',
      data: <String, Object?>{'dramaId': dramaId, 'tag_ids': tagIds},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => _parseRecommendations(data),
    );
  }

  static List<PlayerRecommendationDto> _parseRecommendations(Object? data) {
    if (data is! List) return const <PlayerRecommendationDto>[];
    return data
        .whereType<Map<String, Object?>>()
        .map(PlayerRecommendationDto.fromJson)
        .toList(growable: false);
  }

  Future<PlayerFeedPageDto> listForYouFeed({int page = 1, int pageSize = 20}) {
    return _apiClient.get<PlayerFeedPageDto>(
      '/api/home/play/recommend',
      queryParameters: <String, Object?>{'page': page, 'page_size': pageSize},
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
    return _apiClient
        .get<ShortFollowCheckDto>(
          '/api/user/short/follow/check',
          queryParameters: <String, Object?>{'dramaId': dramaId},
          authPolicy: ApiAuthPolicy.required,
          decoder: (data) => ShortFollowCheckDto.fromJson(
            JsonFieldParser.requireMap(data, dtoName: 'ShortFollowCheckDto'),
          ),
        )
        .then((dto) => dto.followed);
  }

  /// 获取观看进度。
  Future<WatchProgressDto?> fetchWatchProgress({required int dramaId}) {
    return _apiClient.get<WatchProgressDto?>(
      '/api/user/watch/progress',
      queryParameters: <String, Object?>{'dramaId': dramaId},
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) {
        try {
          return WatchProgressDto.fromJson(
            JsonFieldParser.requireMap(data, dtoName: 'WatchProgressDto'),
          );
        } catch (e) {
          // 如果解析失败，返回 null，这样可以正常继续播放
          return null;
        }
      },
    );
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
      decoder: (_) {},
    );
  }

  /// 上报播放器内的分享动作。
  Future<void> reportDramaShareAction({
    required String dramaId,
    required String shareChannel,
  }) {
    return _apiClient.post<void>(
      '/api/activity/task/action/report',
      data: <String, Object?>{
        'actionKey': 'share_drama',
        'extra': <String, String>{
          'drama_id': dramaId,
          'share_channel': shareChannel,
        },
      },
      authPolicy: ApiAuthPolicy.required,
      decoder: (_) {},
    );
  }

  /// 金币解锁剧集。
  ///
  /// 对应后端 API：POST /api/payment/episode/unlock
  Future<PlayerEpisodeUnlockDto> unlockEpisode({
    required bool autoUnlockNext,
    required int coin,
    required int dramaId,
    required int episodeNo,
    required String shortTitle,
    required String cover,
    required int episodeId,
    required String requestId,
  }) {
    return _apiClient.post<PlayerEpisodeUnlockDto>(
      '/api/payment/episode/unlock',
      data: <String, Object?>{
        'autoUnlockNext': autoUnlockNext,
        'coin': coin,
        'cover': cover,
        'dramaId': dramaId,
        'episodeId': episodeId,
        'episodeNo': episodeNo,
        'requestId': requestId,
        'shortTitle': shortTitle,
      }..removeWhere((_, value) => value == null),
      authPolicy: ApiAuthPolicy.required,
      decoder: (data) => PlayerEpisodeUnlockDto.fromJson(
        JsonFieldParser.requireMap(data, dtoName: 'PlayerEpisodeUnlockDto'),
      ),
    );
  }
}
