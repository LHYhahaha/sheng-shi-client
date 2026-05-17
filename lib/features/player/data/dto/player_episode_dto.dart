import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';

/// 播放器剧集远程 DTO。
///
/// DTO 只存在 data 层。`hlsUrl` 不放在这里，真实播放源必须通过 playback-source 接口
/// 单独解析，避免详情接口绕过签名、过期和权益策略。
class PlayerEpisodeDto {
  const PlayerEpisodeDto({
    required this.episodeId,
    required this.dramaId,
    required this.episodeNumber,
    required this.title,
    required this.unlockType,
    required this.requiredCoins,
    required this.isAvailable,
    required this.durationMs,
    required this.aspectRatio,
    required this.posterUrl,
    required this.previewImageUrl,
    this.accessStatus,
    this.reasonCode,
  });

  final String episodeId;
  final String dramaId;
  final int episodeNumber;
  final String? title;
  final String unlockType;
  final int? requiredCoins;
  final bool isAvailable;
  final int? durationMs;
  final double? aspectRatio;
  final String? posterUrl;
  final String? previewImageUrl;
  final String? accessStatus;
  final String? reasonCode;

  factory PlayerEpisodeDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'PlayerEpisodeDto';
    final episodeId =
        JsonFieldParser.optionalString(json, 'episodeId') ??
        JsonFieldParser.optionalString(json, 'id');
    if (episodeId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'episodeId',
        reason: 'required episode id',
      );
    }

    final unlockType = JsonFieldParser.parseUnlockType(json, dtoName: dtoName);
    final requiredCoins = unlockType == 'coins'
        ? JsonFieldParser.requireInt(json, 'requiredCoins', dtoName: dtoName)
        : JsonFieldParser.optionalInt(json, 'requiredCoins');

    return PlayerEpisodeDto(
      episodeId: episodeId,
      dramaId: JsonFieldParser.requireString(json, 'dramaId', dtoName: dtoName),
      episodeNumber:
          JsonFieldParser.optionalInt(json, 'episodeNumber') ??
          JsonFieldParser.optionalInt(json, 'number') ??
          (throw const ApiMappingException(
            dtoName: dtoName,
            field: 'episodeNumber',
            reason: 'required episode number',
          )),
      title: JsonFieldParser.optionalString(json, 'title'),
      unlockType: unlockType,
      requiredCoins: requiredCoins,
      isAvailable: JsonFieldParser.requireBool(
        json,
        'isAvailable',
        dtoName: dtoName,
      ),
      durationMs: JsonFieldParser.optionalInt(json, 'durationMs'),
      aspectRatio: _doubleValue(json['aspectRatio']),
      posterUrl: JsonFieldParser.optionalString(json, 'posterUrl'),
      previewImageUrl: JsonFieldParser.optionalString(json, 'previewImageUrl'),
      accessStatus: _accessStatus(json),
      reasonCode: _reasonCode(json),
    );
  }

  static double? _doubleValue(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
