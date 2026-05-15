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
    this.isAvailable = true,
    this.accessStatus,
    this.reasonCode,
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

  /// 服务端判定该播放源是否当前可用。
  ///
  /// 这个字段只承载 contract，不在 DTO 层做 UI 决策。mapper 会把不可用 source
  /// 收敛为 resolve error，避免播放器打开一个已经被服务端拒绝的 HLS URL。
  final bool isAvailable;

  /// 服务端返回的访问状态，例如 `allowed`、`denied`、`blocked`、`unavailable`。
  ///
  /// 真实接口可把会员/金币/下架/地区限制等原因折叠到这个字段，再配合 reasonCode
  /// 给 application 层做更细的错误或权益刷新处理。
  final String? accessStatus;

  /// 服务端拒播或不可用原因码。
  ///
  /// 当前只透传到 mapper error；后续可映射到 entitlement refresh、source refresh 或
  /// 内容不可用提示，不要让 presentation 直接读取 DTO。
  final String? reasonCode;

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
      isAvailable: _boolValue(json['isAvailable']) ?? true,
      accessStatus:
          _stringValue(json['accessStatus']) ??
          _stringValue(_mapValue(json['access'])['status']),
      reasonCode:
          _stringValue(json['reasonCode']) ??
          _stringValue(_mapValue(json['access'])['reasonCode']),
    );
  }

  bool get hasPlayableHls =>
      isAvailable && hlsUrl != null && hlsUrl!.isNotEmpty && _isAccessAllowed;

  bool get _isAccessAllowed {
    final status = accessStatus?.toLowerCase();
    if (status == null || status.isEmpty) return true;
    return switch (status) {
      'allowed' || 'allow' || 'ok' || 'available' => true,
      _ => false,
    };
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
