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
  });

  final int id;
  final int episodeNo;
  final String videoName;
  final String sourceUrl;
  final int durationSec;
  final int status;
  final String publishedAt;
  final List<PlayerEpisodeSubtitleDto> subtitles;

  factory PlayerEpisodeDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      episodeNo: JsonFieldParser.optionalInt(json, 'episode_no') ?? 0,
      videoName: JsonFieldParser.optionalString(json, 'video_name') ?? '',
      sourceUrl: JsonFieldParser.optionalString(json, 'source_url') ?? '',
      durationSec: JsonFieldParser.optionalInt(json, 'duration_sec') ?? 0,
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
      publishedAt: JsonFieldParser.optionalString(json, 'published_at') ?? '',
      subtitles: _parseSubtitles(json['subtitles']),
    );
  }

  static List<PlayerEpisodeSubtitleDto> _parseSubtitles(Object? value) {
    if (value is! List) return const <PlayerEpisodeSubtitleDto>[];
    return value
        .whereType<Map<String, Object?>>()
        .map(PlayerEpisodeSubtitleDto.fromJson)
        .toList(growable: false);
  }
}

/// 播放器字幕 DTO。
class PlayerEpisodeSubtitleDto {
  const PlayerEpisodeSubtitleDto({
    required this.id,
    required this.language,
    required this.subtitleName,
    required this.subtitleUrl,
    required this.format,
    required this.status,
  });

  final int id;
  final String language;
  final String subtitleName;
  final String subtitleUrl;
  final String format;
  final int status;

  factory PlayerEpisodeSubtitleDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeSubtitleDto(
      id: JsonFieldParser.optionalInt(json, 'id') ?? 0,
      language: JsonFieldParser.optionalString(json, 'language') ?? '',
      subtitleName: JsonFieldParser.optionalString(json, 'subtitle_name') ?? '',
      subtitleUrl: JsonFieldParser.optionalString(json, 'subtitle_url') ?? '',
      format: JsonFieldParser.optionalString(json, 'format') ?? '',
      status: JsonFieldParser.optionalInt(json, 'status') ?? 0,
    );
  }
}
