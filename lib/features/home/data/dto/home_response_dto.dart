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
    required this.page,
    required this.pageSize,
    required this.dramaTotal,
    required this.dramas,
  });

  final int id;
  final String name;
  final String flag;
  final int sort;
  final int status;
  final int page;
  final int pageSize;
  final int dramaTotal;
  final List<HomeDramaDto> dramas;

  factory HomeTabDto.fromJson(Map<String, Object?> json) {
    return HomeTabDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      name: JsonFieldParser.optionalString(json, 'name') ?? '',
      flag: JsonFieldParser.optionalString(json, 'flag') ?? '',
      sort: JsonFieldParser.optionalInt(json, 'sort') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      page: JsonFieldParser.optionalInt(json, 'page') ?? 1,
      pageSize: JsonFieldParser.optionalInt(json, 'page_size') ?? 20,
      dramaTotal: JsonFieldParser.optionalInt(json, 'drama_total') ?? 0,
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
    this.isFavorited = 0,
    this.watchProgress,
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
  final int isFavorited;
  final HomeWatchProgressDto? watchProgress;

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
      isFavorited: JsonFieldParser.optionalInt(json, 'is_favorited') ?? 0,
      watchProgress: HomeWatchProgressDto.fromJsonOrNull(
        json['watch_progress'],
      ),
    );
  }

  static List<String> _parseTagsName(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}

/// 首页剧卡附带的用户观看进度。
///
/// 它与详情接口的 `watch_progress` 使用同一 snake_case 契约，但首页层不依赖
/// 播放器 DTO，避免首页数据模型反向耦合播放器功能。没有观看记录时后端会返回
/// `watch_episode_id=0`、第 1 集和 0 秒；字段缺失时则保留为 null 以兼容旧接口。
class HomeWatchProgressDto {
  const HomeWatchProgressDto({
    required this.watchEpisodeId,
    required this.watchEpisodeNo,
    required this.watchSecond,
    required this.progressPercent,
    required this.durationSecond,
  });

  final int watchEpisodeId;
  final int watchEpisodeNo;
  final int watchSecond;
  final int progressPercent;
  final int durationSecond;

  factory HomeWatchProgressDto.fromJson(Map<String, Object?> json) {
    return HomeWatchProgressDto(
      watchEpisodeId:
          JsonFieldParser.optionalInt(json, 'watch_episode_id') ?? 0,
      watchEpisodeNo:
          JsonFieldParser.optionalInt(json, 'watch_episode_no') ?? 1,
      watchSecond: JsonFieldParser.optionalInt(json, 'watch_second') ?? 0,
      progressPercent:
          JsonFieldParser.optionalInt(json, 'progress_percent') ?? 0,
      durationSecond: JsonFieldParser.optionalInt(json, 'duration_second') ?? 0,
    );
  }

  static HomeWatchProgressDto? fromJsonOrNull(Object? value) {
    if (value is! Map) return null;
    return HomeWatchProgressDto.fromJson(Map<String, Object?>.from(value));
  }
}
