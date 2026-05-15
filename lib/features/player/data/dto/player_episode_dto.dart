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

  /// 服务端访问状态预留字段。
  ///
  /// 详情/剧集列表只描述“这一集是否能进入权益判断”，真实播放 URL 仍由
  /// playback-source 接口给出。这里保留 access 信息是为了后续把下架、地区限制、
  /// 会员限制等原因映射到 Entitlement，而不是让 PlayerPage 猜。
  final String? accessStatus;

  /// 服务端不可用/拒绝访问原因码，当前只作为 contract 预留。
  final String? reasonCode;

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
      accessStatus:
          _stringValue(json['accessStatus']) ??
          _stringValue(_mapValue(json['access'])['status']),
      reasonCode:
          _stringValue(json['reasonCode']) ??
          _stringValue(_mapValue(json['access'])['reasonCode']),
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

  static Map<String, Object?> _mapValue(Object? value) {
    if (value is Map<String, Object?>) return value;
    return const <String, Object?>{};
  }
}
