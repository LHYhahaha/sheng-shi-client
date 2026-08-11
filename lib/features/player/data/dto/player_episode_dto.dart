import '../../../../core/network/json_field_parser.dart';

/// 播放器剧集远程 DTO。
///
/// 用于接收短剧详情 API 返回的集数数据。
class PlayerEpisodeDto {
  const PlayerEpisodeDto({
    required this.id,
    required this.episodeNo,
    required this.videoName,
    required this.sourceUrl,
    required this.durationSec,
    required this.status,
    required this.publishedAt,
    required this.subtitles,
    required this.isUnlocked,
    required this.isVipOnly,
    this.viewingEntitlementType,
    this.episodeSources = const [],
    this.adUnlock,
  });

  final int id;
  final int episodeNo;
  final String videoName;
  final String sourceUrl;
  final int durationSec;
  final int status;
  final String publishedAt;
  final List<PlayerEpisodeSubtitleDto> subtitles;
  final List<PlayerEpisodeSourceDto> episodeSources;

  /// 当前用户是否已解锁该集。
  ///
  /// 0 = 未解锁，1 = 已解锁。用于判断是否需要付费或会员权限。
  final int isUnlocked;

  /// 该集是否为会员专属。
  ///
  /// 0 = 非会员专属，1 = 会员专属。
  final int isVipOnly;

  /// 当前用户观看该集的实际权益来源；由详情接口返回。
  final String? viewingEntitlementType;
  final PlayerEpisodeAdUnlockDto? adUnlock;

  factory PlayerEpisodeDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      episodeNo: JsonFieldParser.optionalInt(json, 'episode_no') ?? 0,
      videoName: JsonFieldParser.optionalString(json, 'video_name') ?? '',
      sourceUrl:
          // "https://cdn.nq1st.cc/nono/AppleHLS1/nono.m3u8",
          JsonFieldParser.optionalString(json, 'source_url') ?? '',
      durationSec: JsonFieldParser.optionalInt(json, 'duration_sec') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      publishedAt: JsonFieldParser.optionalString(json, 'published_at') ?? '',
      subtitles: _parseSubtitles(json['subtitles']),
      episodeSources: _parseEpisodeSources(json['episode_sources']),
      isUnlocked: JsonFieldParser.optionalInt(json, 'is_unlocked') ?? 0,
      isVipOnly: JsonFieldParser.optionalInt(json, 'is_vip_only') ?? 0,
      viewingEntitlementType: JsonFieldParser.optionalString(
        json,
        'viewing_entitlement_type',
      ),
      adUnlock: PlayerEpisodeAdUnlockDto.fromJsonOrNull(json['ad_unlock']),
    );
  }

  static List<PlayerEpisodeSubtitleDto> _parseSubtitles(Object? value) {
    if (value is! List) return const <PlayerEpisodeSubtitleDto>[];
    return value
        .whereType<Map<String, Object?>>()
        .map(PlayerEpisodeSubtitleDto.fromJson)
        .toList(growable: false);
  }

  static List<PlayerEpisodeSourceDto> _parseEpisodeSources(Object? value) {
    if (value is! List) return const <PlayerEpisodeSourceDto>[];
    return value
        .whereType<Map<String, Object?>>()
        .map(PlayerEpisodeSourceDto.fromJson)
        .toList(growable: false);
  }
}

class PlayerEpisodeAdUnlockDto {
  const PlayerEpisodeAdUnlockDto({
    required this.available,
    required this.watchedToday,
    required this.dailyLimit,
    required this.closeAfterSec,
    this.placementId,
    this.adVideoUrl,
    this.taskToken,
  });

  final bool available;
  final int watchedToday;
  final int dailyLimit;
  final int closeAfterSec;
  final String? placementId;
  final String? adVideoUrl;
  final String? taskToken;

  static PlayerEpisodeAdUnlockDto? fromJsonOrNull(Object? value) {
    if (value is! Map<String, Object?>) return null;
    return PlayerEpisodeAdUnlockDto(
      available: JsonFieldParser.optionalBool(value, 'available') ?? false,
      watchedToday: JsonFieldParser.optionalInt(value, 'watched_today') ?? 0,
      dailyLimit: JsonFieldParser.optionalInt(value, 'daily_limit') ?? 0,
      closeAfterSec: JsonFieldParser.optionalInt(value, 'close_after_sec') ?? 0,
      placementId: JsonFieldParser.optionalString(value, 'placement_id'),
      adVideoUrl: JsonFieldParser.optionalString(value, 'ad_video_url'),
      taskToken: JsonFieldParser.optionalString(value, 'task_token'),
    );
  }
}

/// 播放器字幕 DTO。
class PlayerEpisodeSubtitleDto {
  const PlayerEpisodeSubtitleDto({
    required this.id,
    required this.language,
    required this.languageCode,
    required this.subtitleName,
    required this.subtitleUrl,
    required this.format,
    required this.status,
    this.subtitlePosition = '1',
  });

  final int id;
  final String language;
  final String languageCode;
  final String subtitleName;
  final String subtitleUrl;
  final String format;
  final int status;
  final String subtitlePosition;

  factory PlayerEpisodeSubtitleDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeSubtitleDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      language: JsonFieldParser.optionalString(json, 'language') ?? '',
      languageCode: JsonFieldParser.optionalString(json, 'language_code') ?? '',
      subtitleName: JsonFieldParser.optionalString(json, 'subtitle_name') ?? '',
      subtitleUrl: JsonFieldParser.optionalString(json, 'subtitle_url') ?? '',
      format: JsonFieldParser.optionalString(json, 'format') ?? '',
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      // 接口文档定义为 string，但实际响应可能返回 number（例如 2）。
      // 统一转换为字符串后，由 mapper 映射到播放器位置。
      subtitlePosition: json['subtitle_position']?.toString() ?? '1',
    );
  }
}

class PlayerEpisodeSourceDto {
  const PlayerEpisodeSourceDto({
    required this.id,
    required this.language,
    required this.languageCode,
    required this.sourceUrl,
    required this.status,
  });

  final String id;
  final String language;
  final String languageCode;
  final String sourceUrl;
  final int status;

  factory PlayerEpisodeSourceDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeSourceDto(
      id: json['id']?.toString() ?? '',
      language: JsonFieldParser.optionalString(json, 'language') ?? '',
      languageCode: JsonFieldParser.optionalString(json, 'language_code') ?? '',
      sourceUrl: JsonFieldParser.optionalString(json, 'source_url') ?? '',
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
    );
  }
}
