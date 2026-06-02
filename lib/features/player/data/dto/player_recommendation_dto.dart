import '../../../../core/network/json_field_parser.dart';

/// 播放器推荐项远程 DTO。
///
/// 接收推荐 API 返回的数据格式，用于详情弹层的"猜你喜欢"推荐列表。
class PlayerRecommendationDto {
  const PlayerRecommendationDto({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.tagsName,
    required this.playCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    required this.episodeTotal,
  });

  final int id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final List<String> tagsName;
  final int playCount;
  final int trailerEpisodeNum;
  final int isVipOnly;
  final int status;
  final int episodeTotal;

  factory PlayerRecommendationDto.fromJson(Map<String, Object?> json) {
    return PlayerRecommendationDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
      tagsName: _parseTagsName(json['tags_name']),
      playCount: JsonFieldParser.optionalInt(json, 'play_count') ?? 0,
      trailerEpisodeNum: JsonFieldParser.optionalInt(json, 'trailer_episode_num') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      episodeTotal: JsonFieldParser.optionalInt(json, 'episode_total') ?? 0,
    );
  }

  static List<String> _parseTagsName(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
