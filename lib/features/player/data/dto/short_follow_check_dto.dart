import '../../../../core/network/json_field_parser.dart';

/// 短剧点赞状态检查 DTO。
class ShortFollowCheckDto {
  const ShortFollowCheckDto({
    required this.followed,
  });

  /// 是否已点赞。
  final bool followed;

  factory ShortFollowCheckDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'ShortFollowCheckDto';

    return ShortFollowCheckDto(
      followed: JsonFieldParser.optionalBool(json, 'followed') ?? false,
    );
  }
}
