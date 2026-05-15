/// 首页分类远程 DTO。
///
/// DTO 只属于 data 层，字段尽量贴近接口返回；presentation/application 不应 import 它。
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
    return DramaCategoryDto(
      id: _stringValue(json['id']) ?? '',
      title: _stringValue(json['title']) ?? '',
      sortOrder: _intValue(json['sortOrder']) ?? 0,
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
}
