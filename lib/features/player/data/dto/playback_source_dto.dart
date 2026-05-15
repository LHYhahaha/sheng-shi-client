import 'subtitle_track_dto.dart';

/// 播放源远程 DTO。
///
/// 这里保留 subtitle/preview/cache/preload 合约字段，即使当前 domain 暂未消费，也避免
/// 后续接真实接口时把字段散落到播放器 UI。
class PlaybackSourceDto {
  const PlaybackSourceDto({
    required this.episodeId,
    required this.sourceId,
    required this.hlsUrl,
    required this.backupHlsUrls,
    required this.expiresAt,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.codec,
    required this.cachePolicy,
    required this.preloadPolicy,
    required this.subtitleTracks,
    required this.previewSpriteUrl,
    required this.previewVttUrl,
  });

  final String episodeId;
  final String sourceId;
  final String? hlsUrl;
  final List<String> backupHlsUrls;
  final DateTime? expiresAt;
  final int? durationMs;
  final int? width;
  final int? height;
  final double? aspectRatio;
  final String? codec;
  final Map<String, Object?> cachePolicy;
  final Map<String, Object?> preloadPolicy;
  final List<SubtitleTrackDto> subtitleTracks;
  final String? previewSpriteUrl;
  final String? previewVttUrl;

  factory PlaybackSourceDto.fromJson(Map<String, Object?> json) {
    final rawSubtitles = json['subtitleTracks'];
    return PlaybackSourceDto(
      episodeId: _stringValue(json['episodeId']) ?? '',
      sourceId: _stringValue(json['sourceId']) ?? '',
      hlsUrl: _stringValue(json['hlsUrl']),
      backupHlsUrls: _stringList(json['backupHlsUrls']),
      expiresAt: _dateTimeValue(json['expiresAt']),
      durationMs: _intValue(json['durationMs']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      aspectRatio: _doubleValue(json['aspectRatio']),
      codec: _stringValue(json['codec']),
      cachePolicy: _mapValue(json['cachePolicy']),
      preloadPolicy: _mapValue(json['preloadPolicy']),
      subtitleTracks: rawSubtitles is List
          ? rawSubtitles
                .whereType<Map<String, Object?>>()
                .map(SubtitleTrackDto.fromJson)
                .toList(growable: false)
          : const <SubtitleTrackDto>[],
      previewSpriteUrl: _stringValue(json['previewSpriteUrl']),
      previewVttUrl: _stringValue(json['previewVttUrl']),
    );
  }

  bool get hasPlayableHls => hlsUrl != null && hlsUrl!.isNotEmpty;

  static String? _stringValue(Object? value) => value is String ? value : null;

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _doubleValue(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _dateTimeValue(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }

  static Map<String, Object?> _mapValue(Object? value) {
    if (value is Map<String, Object?>) return value;
    return const <String, Object?>{};
  }
}
