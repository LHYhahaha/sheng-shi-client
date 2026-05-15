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

  factory PlayerEpisodeDto.fromJson(Map<String, Object?> json) {
    return PlayerEpisodeDto(
      episodeId:
          _stringValue(json['episodeId']) ?? _stringValue(json['id']) ?? '',
      dramaId: _stringValue(json['dramaId']) ?? '',
      episodeNumber:
          _intValue(json['episodeNumber']) ?? _intValue(json['number']) ?? 0,
      title: _stringValue(json['title']),
      unlockType: _stringValue(json['unlockType']) ?? 'free',
      requiredCoins: _intValue(json['requiredCoins']),
      isAvailable: _boolValue(json['isAvailable']) ?? true,
      durationMs: _intValue(json['durationMs']),
      aspectRatio: _doubleValue(json['aspectRatio']),
      posterUrl: _stringValue(json['posterUrl']),
      previewImageUrl: _stringValue(json['previewImageUrl']),
    );
  }

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

  static bool? _boolValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return switch (value.toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => null,
      };
    }
    return null;
  }
}
