import '../../../../core/network/json_field_parser.dart';

class SearchRankingResponseDto {
  const SearchRankingResponseDto({required this.limit, required this.dramas});

  final int limit;
  final List<SearchRankDramaDto> dramas;

  factory SearchRankingResponseDto.fromJson(Map<String, Object?> json) {
    return SearchRankingResponseDto(
      limit: JsonFieldParser.optionalInt(json, 'limit') ?? 0,
      dramas: _parseDramas(json['dramas']),
    );
  }

  static List<SearchRankDramaDto> _parseDramas(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) =>
              SearchRankDramaDto.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }
}

class SearchRankDramaDto {
  const SearchRankDramaDto({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.tagsName,
    required this.searchCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
  });

  final int id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final List<String> tagsName;
  final int searchCount;
  final int trailerEpisodeNum;
  final int isVipOnly;
  final int status;

  factory SearchRankDramaDto.fromJson(Map<String, Object?> json) {
    return SearchRankDramaDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
      tagsName: _parseTags(json['tags_name']),
      searchCount:
          JsonFieldParser.optionalInt(json, 'search_count') ??
          JsonFieldParser.optionalInt(json, 'play_count') ??
          0,
      trailerEpisodeNum:
          JsonFieldParser.optionalInt(json, 'trailer_episode_num') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
    );
  }

  static List<String> _parseTags(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}
