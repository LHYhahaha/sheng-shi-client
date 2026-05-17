import '../../../../core/network/json_field_parser.dart';

/// 收藏条目远程 DTO。
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
  final String? title;
  final String? description;
  final String? coverUrl;
  final double? coverAspectRatio;
  final int totalEpisodes;
  final int? latestEpisodeNumber;
  final List<String> tags;
  final List<String> badges;
  final DateTime? createdAt;

  factory FavoriteItemDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'FavoriteItemDto';
    return FavoriteItemDto(
      favoriteId: JsonFieldParser.optionalString(json, 'favoriteId'),
      dramaId: JsonFieldParser.requireString(json, 'dramaId', dtoName: dtoName),
      title: JsonFieldParser.optionalString(json, 'title'),
      description:
          JsonFieldParser.optionalString(json, 'description') ??
          JsonFieldParser.optionalString(json, 'introduction'),
      coverUrl: JsonFieldParser.optionalString(json, 'coverUrl'),
      coverAspectRatio: _doubleValue(json['coverAspectRatio']),
      totalEpisodes: JsonFieldParser.optionalInt(json, 'totalEpisodes') ?? 0,
      latestEpisodeNumber: JsonFieldParser.optionalInt(
        json,
        'latestEpisodeNumber',
      ),
      tags: _stringList(json['tags']),
      badges: _stringList(json['badges']),
      createdAt: JsonFieldParser.optionalDateTime(json, 'createdAt'),
    );
  }
}

double? _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}
