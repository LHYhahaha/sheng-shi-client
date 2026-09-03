import '../../../../core/network/json_field_parser.dart';

/// 当前用户当天的短剧分享奖励状态。
class ShareDramaStatusDto {
  const ShareDramaStatusDto({
    required this.claimed,
    required this.completed,
    required this.info,
  });

  final bool claimed;
  final bool completed;
  final ShareDramaTaskInfoDto info;

  int get shareCoin => info.minValue;
  String get taskKey => info.configKey;
  bool get hasCompletedTask => claimed || completed;

  factory ShareDramaStatusDto.fromJson(Map<String, Object?> json) {
    final info = JsonFieldParser.requireMap(
      json['info'],
      dtoName: 'ShareDramaTaskInfoDto',
      field: 'info',
    );
    return ShareDramaStatusDto(
      claimed: JsonFieldParser.optionalBool(json, 'claimed') ?? false,
      completed: JsonFieldParser.optionalBool(json, 'completed') ?? false,
      info: ShareDramaTaskInfoDto.fromJson(info),
    );
  }
}

class ShareDramaTaskInfoDto {
  const ShareDramaTaskInfoDto({
    required this.configKey,
    required this.minValue,
  });

  final String configKey;
  final int minValue;

  factory ShareDramaTaskInfoDto.fromJson(Map<String, Object?> json) =>
      ShareDramaTaskInfoDto(
        configKey: JsonFieldParser.optionalString(json, 'configKey') ?? '',
        minValue: JsonFieldParser.optionalInt(json, 'minValue') ?? 0,
      );
}
