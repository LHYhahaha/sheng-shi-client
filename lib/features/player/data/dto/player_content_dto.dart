import '../../../../core/network/json_field_parser.dart';
import 'player_episode_dto.dart';
import 'watch_progress_dto.dart';

/// 播放器剧详情远程 DTO。
///
/// 接收短剧详情 API 返回的数据格式，包含剧的完整信息和所有集数。
class PlayerContentDto {
  const PlayerContentDto({
    required this.id,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.categoryIds,
    required this.tagIds,
    this.tagsName = const [],
    required this.trailerEpisodeNum,
    required this.pricePerEpisode,
    required this.isVipOnly,
    required this.status,
    required this.languageMask,
    required this.subtitleLangs,
    required this.playCount,
    required this.favoriteCount,
    this.isFavorited,
    required this.episodeTotal,
    required this.onlineAt,
    required this.episodes,
    this.watchProgress,
  });

  final int id;
  final String coverUrl;
  final String title;
  final String summary;
  final List<int> categoryIds;
  final List<int> tagIds;
  final List<String> tagsName;
  final int trailerEpisodeNum;
  final int pricePerEpisode;
  final int isVipOnly;
  final int status;
  final String languageMask;
  final String subtitleLangs;
  final int playCount;
  final int favoriteCount;

  /// `null` means the current endpoint did not include the user's status.
  final bool? isFavorited;
  final int episodeTotal;
  final String onlineAt;
  final List<PlayerEpisodeDto> episodes;

  /// `/api/home/detail` 内联的当前用户续播记录。
  ///
  /// 它是普通播放器进入时选集/选续播位置的权威数据；不存在观看记录时接口仍会
  /// 返回 episodeId=0、watchSecond=0 的对象，解析后保持为非 null，便于与旧接口
  /// 的 null 语义区分。
  final WatchProgressDto? watchProgress;

  factory PlayerContentDto.fromJson(Map<String, Object?> json) {
    return PlayerContentDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
      categoryIds: _parseIntList(json['category_ids']),
      tagIds: _parseIntList(json['tag_ids']),
      tagsName: _parseStringList(json['tags_name']),
      trailerEpisodeNum:
          JsonFieldParser.optionalInt(json, 'trailer_episode_num') ?? 0,
      pricePerEpisode:
          JsonFieldParser.optionalInt(json, 'price_per_episode') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      languageMask: JsonFieldParser.optionalString(json, 'language_mask') ?? '',
      subtitleLangs:
          JsonFieldParser.optionalString(json, 'subtitle_langs') ?? '',
      playCount: JsonFieldParser.optionalInt(json, 'play_count') ?? 0,
      favoriteCount: JsonFieldParser.optionalInt(json, 'favorite_count') ?? 0,
      isFavorited: _boolFromFlag(json['is_favorited']),
      episodeTotal: JsonFieldParser.optionalInt(json, 'episode_total') ?? 0,
      onlineAt: JsonFieldParser.optionalString(json, 'online_at') ?? '',
      episodes: _parseEpisodes(json['episodes']),
      watchProgress: WatchProgressDto.fromDetailJsonOrNull(
        json['watch_progress'],
        dramaId: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      ),
    );
  }

  static bool? _boolFromFlag(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return switch (value.trim().toLowerCase()) {
        '1' || 'true' => true,
        '0' || 'false' => false,
        _ => null,
      };
    }
    return null;
  }

  static List<int> _parseIntList(Object? value) {
    if (value is! List) return const <int>[];
    return value.whereType<int>().toList(growable: false);
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .where((tag) => tag.trim().isNotEmpty)
        .map((tag) => tag.trim())
        .toList(growable: false);
  }

  static List<PlayerEpisodeDto> _parseEpisodes(Object? value) {
    if (value is! List) return const <PlayerEpisodeDto>[];
    return value
        .whereType<Map<String, Object?>>()
        .map(PlayerEpisodeDto.fromJson)
        .toList(growable: false);
  }
}
