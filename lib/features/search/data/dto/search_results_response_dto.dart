import '../../../drama/data/dto/drama_trial_dto.dart';
import '../../../../core/network/json_field_parser.dart';
import '../../../drama/data/dto/drama_watch_progress_dto.dart';

class SearchResultsResponseDto {
  const SearchResultsResponseDto({
    required this.keyword,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.dramas,
    required this.guessLike,
  });

  final String keyword;
  final int page;
  final int pageSize;
  final int total;
  final List<SearchResultDramaDto> dramas;
  final List<SearchResultDramaDto> guessLike;

  factory SearchResultsResponseDto.fromJson(Map<String, Object?> json) {
    return SearchResultsResponseDto(
      keyword: JsonFieldParser.optionalString(json, 'keyword') ?? '',
      page: JsonFieldParser.optionalInt(json, 'page') ?? 1,
      pageSize: JsonFieldParser.optionalInt(json, 'page_size') ?? 20,
      total: JsonFieldParser.optionalInt(json, 'total') ?? 0,
      dramas: _parseDramas(json['dramas']),
      guessLike: _parseDramas(json['guess_like']),
    );
  }

  static List<SearchResultDramaDto> _parseDramas(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) =>
              SearchResultDramaDto.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }
}

class SearchResultDramaDto {
  const SearchResultDramaDto({
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
    this.watchProgress,
    this.trial,
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
  final DramaWatchProgressDto? watchProgress;
  final DramaTrialDto? trial;

  factory SearchResultDramaDto.fromJson(Map<String, Object?> json) {
    return SearchResultDramaDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
      tagsName: _parseStrings(json['tags_name']),
      categoryNames: _parseStrings(json['category_names']),
      playCount: JsonFieldParser.optionalInt(json, 'play_count') ?? 0,
      trailerEpisodeNum:
          JsonFieldParser.optionalInt(json, 'trailer_episode_num') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      episodeTotal: JsonFieldParser.optionalInt(json, 'episode_total') ?? 0,
      trial: DramaTrialDto.fromJsonOrNull(json['trial']),
      watchProgress: DramaWatchProgressDto.fromJsonOrNull(
        json['watch_progress'],
      ),
    );
  }

  static List<String> _parseStrings(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }
}
