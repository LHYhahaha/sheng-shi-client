import '../../../../core/network/json_field_parser.dart';

/// 首页响应 DTO。
class HomeResponseDto {
  const HomeResponseDto({
    required this.id,
    required this.name,
    required this.status,
    required this.tabs,
  });

  final int id;
  final String name;
  final int status;
  final List<HomeTabDto> tabs;

  factory HomeResponseDto.fromJson(Map<String, Object?> json) {
    return HomeResponseDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      name: JsonFieldParser.optionalString(json, 'name') ?? '',
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      tabs: _parseTabs(json['tabs']),
    );
  }

  static List<HomeTabDto> _parseTabs(Object? value) {
    if (value is! List) return const <HomeTabDto>[];
    return value
        .whereType<Map>()
        .map((item) => HomeTabDto.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }
}

/// 首页标签页 DTO。
class HomeTabDto {
  const HomeTabDto({
    required this.id,
    required this.name,
    required this.flag,
    required this.sort,
    required this.status,
    required this.dramas,
  });

  final int id;
  final String name;
  final String flag;
  final int sort;
  final int status;
  final List<HomeDramaDto> dramas;

  factory HomeTabDto.fromJson(Map<String, Object?> json) {
    return HomeTabDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      name: JsonFieldParser.optionalString(json, 'name') ?? '',
      flag: JsonFieldParser.optionalString(json, 'flag') ?? '',
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      dramas: _parseDramas(json['dramas']),
    );
  }

  static List<HomeDramaDto> _parseDramas(Object? value) {
    if (value is! List) return const <HomeDramaDto>[];
    return value
        .whereType<Map>()
        .map((item) => HomeDramaDto.fromJson(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }
}

/// 首页剧卡 DTO。
class HomeDramaDto {
  const HomeDramaDto({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.playCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    required this.episodeTotal,
    required this.tagsName,
  });

  final int id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final int playCount;
  final int trailerEpisodeNum;
  final int isVipOnly;
  final int status;
  final int episodeTotal;
  final List<String> tagsName;

  factory HomeDramaDto.fromJson(Map<String, Object?> json) {
    return HomeDramaDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      coverUrl: JsonFieldParser.optionalString(json, 'cover_url') ?? '',
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      summary: JsonFieldParser.optionalString(json, 'summary') ?? '',
      playCount: JsonFieldParser.optionalInt(json, 'play_count') ?? 0,
      trailerEpisodeNum:
          JsonFieldParser.optionalInt(json, 'trailer_episode_num') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      episodeTotal: JsonFieldParser.optionalInt(json, 'episode_total') ?? 0,
      tagsName: _parseTagsName(json['tags_name']),
    );
  }

  static List<String> _parseTagsName(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
