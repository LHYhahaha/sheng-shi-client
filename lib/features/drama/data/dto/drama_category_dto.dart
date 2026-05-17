import '../../../../core/network/json_field_parser.dart';

/// 首页分类远程 DTO。
class DramaCategoryDto {
  const DramaCategoryDto({
    required this.id,
    required this.title,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final int sortOrder;

  factory DramaCategoryDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'DramaCategoryDto';
    return DramaCategoryDto(
      id: JsonFieldParser.requireString(json, 'id', dtoName: dtoName),
      title: JsonFieldParser.optionalString(json, 'title') ?? '',
      sortOrder: JsonFieldParser.optionalInt(json, 'sortOrder') ?? 0,
    );
  }
}
