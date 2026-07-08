import '../../../../core/network/json_field_parser.dart';
import '../../domain/popup.dart';

class PopupExitRecommendationResponseDto {
  const PopupExitRecommendationResponseDto({required this.dramas});

  final List<PopupExitRecommendationDto> dramas;

  factory PopupExitRecommendationResponseDto.fromJson(
    Map<String, Object?> json,
  ) {
    return PopupExitRecommendationResponseDto(
      dramas: _parseDramas(json['dramas']),
    );
  }

  static List<PopupExitRecommendationDto> _parseDramas(Object? value) {
    if (value is! List) return const <PopupExitRecommendationDto>[];
    return value
        .whereType<Map>()
        .map((item) {
          return PopupExitRecommendationDto.fromJson(
            Map<String, Object?>.from(item),
          );
        })
        .toList(growable: false);
  }
}

class PopupExitRecommendationDto {
  const PopupExitRecommendationDto({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.tagsName,
    required this.categoryNames,
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
  final List<String> categoryNames;
  final int playCount;
  final int trailerEpisodeNum;
  final int isVipOnly;
  final int status;
  final int episodeTotal;

  factory PopupExitRecommendationDto.fromJson(Map<String, Object?> json) {
    return PopupExitRecommendationDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
      tagsName: _parseStringList(json['tags_name']),
      categoryNames: _parseStringList(json['category_names']),
      playCount: JsonFieldParser.optionalInt(json, 'play_count') ?? 0,
      trailerEpisodeNum:
          JsonFieldParser.optionalInt(json, 'trailer_episode_num') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      episodeTotal: JsonFieldParser.optionalInt(json, 'episode_total') ?? 0,
    );
  }

  PopupExitRecommendation toDomain() {
    return PopupExitRecommendation(
      id: id,
      sort: sort,
      coverUrl: coverUrl,
      title: title,
      summary: summary,
      tagsName: tagsName,
      categoryNames: categoryNames,
      playCount: playCount,
      trailerEpisodeNum: trailerEpisodeNum,
      isVipOnly: isVipOnly,
      status: status,
      episodeTotal: episodeTotal,
    );
  }

  static List<String> _parseStringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
