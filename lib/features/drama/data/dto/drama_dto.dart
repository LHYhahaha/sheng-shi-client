import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';

/// 首页剧卡远程 DTO。
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
  final String? title;
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
    const dtoName = 'DramaDto';
    final dramaId =
        JsonFieldParser.optionalString(json, 'dramaId') ??
        JsonFieldParser.optionalString(json, 'id');
    if (dramaId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'dramaId',
        reason: 'required drama id',
      );
    }

    return DramaDto(
      dramaId: dramaId,
      title: JsonFieldParser.optionalString(json, 'title'),
      description: JsonFieldParser.optionalString(json, 'description'),
      coverUrl: JsonFieldParser.optionalString(json, 'coverUrl'),
      posterUrl: JsonFieldParser.optionalString(json, 'posterUrl'),
      viewCount: JsonFieldParser.optionalInt(json, 'viewCount'),
      viewCountLabel: JsonFieldParser.optionalString(json, 'viewCountLabel'),
      episodeCount: JsonFieldParser.optionalInt(json, 'episodeCount') ?? 0,
      tags: _stringList(json['tags']),
      badges: _stringList(json['badges']),
      categoryIds: _stringList(json['categoryIds']),
      coverAspectRatio: _doubleValue(json['coverAspectRatio']),
    );
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
}
