/// 收藏条目远程 DTO。
///
/// 只存在 data 层。收藏删除接口以后仍以 dramaId 为主，favoriteId 只是服务端收藏记录
/// id，不能替代剧集业务 id。
class FavoriteItemDto {
  const FavoriteItemDto({
    required this.favoriteId,
    required this.dramaId,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.coverAspectRatio,
    required this.totalEpisodes,
    required this.latestEpisodeNumber,
    required this.tags,
    required this.badges,
    required this.createdAt,
  });

  final String? favoriteId;
  final String dramaId;
  final String title;
  final String? description;
  final String? coverUrl;
  final double? coverAspectRatio;
  final int totalEpisodes;
  final int? latestEpisodeNumber;
  final List<String> tags;
  final List<String> badges;
  final DateTime? createdAt;

  factory FavoriteItemDto.fromJson(Map<String, Object?> json) {
    return FavoriteItemDto(
      favoriteId: _stringValue(json['favoriteId']),
      dramaId: _stringValue(json['dramaId']) ?? '',
      title: _stringValue(json['title']) ?? '',
      description:
          _stringValue(json['description']) ??
          _stringValue(json['introduction']),
      coverUrl: _stringValue(json['coverUrl']),
      coverAspectRatio: _doubleValue(json['coverAspectRatio']),
      totalEpisodes: _intValue(json['totalEpisodes']) ?? 0,
      latestEpisodeNumber: _intValue(json['latestEpisodeNumber']),
      tags: _stringList(json['tags']),
      badges: _stringList(json['badges']),
      createdAt: _dateTimeValue(json['createdAt']),
    );
  }
}

String? _stringValue(Object? value) => value is String ? value : null;

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}
