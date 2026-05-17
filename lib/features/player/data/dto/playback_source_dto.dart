import '../../../../core/network/json_field_parser.dart';
import 'subtitle_track_dto.dart';

/// 播放源远程 DTO。
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
    required this.isAvailable,
    this.accessStatus,
    this.reasonCode,
  });

  final String episodeId;
  final String sourceId;
  final String hlsUrl;
  final List<String> backupHlsUrls;
  final DateTime expiresAt;
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
  final bool isAvailable;
  final String? accessStatus;
  final String? reasonCode;

  factory PlaybackSourceDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'PlaybackSourceDto';
    final rawSubtitles = json['subtitleTracks'];
    return PlaybackSourceDto(
      episodeId: JsonFieldParser.requireString(
        json,
        'episodeId',
        dtoName: dtoName,
      ),
      sourceId: JsonFieldParser.requireString(
        json,
        'sourceId',
        dtoName: dtoName,
      ),
      hlsUrl: JsonFieldParser.requireString(json, 'hlsUrl', dtoName: dtoName),
      backupHlsUrls: _stringList(json['backupHlsUrls']),
      expiresAt: JsonFieldParser.requireDateTime(
        json,
        'expiresAt',
        dtoName: dtoName,
      ),
      durationMs: JsonFieldParser.optionalInt(json, 'durationMs'),
      width: JsonFieldParser.optionalInt(json, 'width'),
      height: JsonFieldParser.optionalInt(json, 'height'),
      aspectRatio: _doubleValue(json['aspectRatio']),
      codec: JsonFieldParser.optionalString(json, 'codec'),
      cachePolicy: _mapValue(json['cachePolicy']),
      preloadPolicy: _mapValue(json['preloadPolicy']),
      subtitleTracks: rawSubtitles is List
          ? rawSubtitles
                .whereType<Map<String, Object?>>()
                .map(SubtitleTrackDto.fromJson)
                .toList(growable: false)
          : const <SubtitleTrackDto>[],
      previewSpriteUrl: JsonFieldParser.optionalString(
        json,
        'previewSpriteUrl',
      ),
      previewVttUrl: JsonFieldParser.optionalString(json, 'previewVttUrl'),
      isAvailable: JsonFieldParser.requireBool(
        json,
        'isAvailable',
        dtoName: dtoName,
      ),
      accessStatus: _accessStatus(json),
      reasonCode: _reasonCode(json),
    );
  }

  bool get hasPlayableHls =>
      isAvailable && hlsUrl.isNotEmpty && _isAccessAllowed;

  bool get _isAccessAllowed {
    final status = accessStatus?.toLowerCase();
    if (status == null || status.isEmpty) return true;
    return switch (status) {
      'allowed' || 'allow' || 'ok' || 'available' => true,
      _ => false,
    };
  }

  static double? _doubleValue(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
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

  static String? _accessStatus(Map<String, Object?> json) {
    final direct = JsonFieldParser.optionalString(json, 'accessStatus');
    if (direct != null) return direct;
    return JsonFieldParser.optionalString(_mapValue(json['access']), 'status');
  }

  static String? _reasonCode(Map<String, Object?> json) {
    final direct = JsonFieldParser.optionalString(json, 'reasonCode');
    if (direct != null) return direct;
    return JsonFieldParser.optionalString(
      _mapValue(json['access']),
      'reasonCode',
    );
  }
}
