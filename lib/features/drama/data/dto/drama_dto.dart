/// 首页剧卡远程 DTO。
///
/// 这里保留 raw/display 两类字段：例如 `viewCount` 用于后续排序/埋点，
/// `viewCountLabel` 只用于展示。mapper 负责转换到当前 Home domain model。
class DramaDto {
  const DramaDto({
    required this.dramaId,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.posterUrl,
    required this.viewCount,
    required this.viewCountLabel,
    required this.episodeCount,
    required this.tags,
    required this.badges,
    required this.categoryIds,
    required this.coverAspectRatio,
  });

  final String dramaId;
  final String title;
  final String? description;
  final String? coverUrl;
  final String? posterUrl;
  final int? viewCount;
  final String? viewCountLabel;
  final int episodeCount;
  final List<String> tags;
  final List<String> badges;
  final List<String> categoryIds;
  final double? coverAspectRatio;

  factory DramaDto.fromJson(Map<String, Object?> json) {
    return DramaDto(
      dramaId: _stringValue(json['dramaId']) ?? _stringValue(json['id']) ?? '',
      title: _stringValue(json['title']) ?? '',
      description: _stringValue(json['description']),
      coverUrl: _stringValue(json['coverUrl']),
      posterUrl: _stringValue(json['posterUrl']),
      viewCount: _intValue(json['viewCount']),
      viewCountLabel: _stringValue(json['viewCountLabel']),
      episodeCount: _intValue(json['episodeCount']) ?? 0,
      tags: _stringList(json['tags']),
      badges: _stringList(json['badges']),
      categoryIds: _stringList(json['categoryIds']),
      coverAspectRatio: _doubleValue(json['coverAspectRatio']),
    );
  }

  static String? _stringValue(Object? value) {
    return value is String ? value : null;
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _doubleValue(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }
}
