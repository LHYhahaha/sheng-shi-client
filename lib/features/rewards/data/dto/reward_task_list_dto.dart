import '../../../../core/network/json_field_parser.dart';
import '../../domain/reward_task.dart';

class RewardTaskListDto {
  const RewardTaskListDto({required this.items});

  final List<RewardTaskDto> items;

  factory RewardTaskListDto.fromJson(Map<String, Object?> json) {
    return RewardTaskListDto(
      items:
          JsonFieldParser.requireList(
                json['items'],
                dtoName: 'RewardTaskListDto',
                field: 'items',
              )
              .map(
                (item) => RewardTaskDto.fromJson(
                  JsonFieldParser.requireMap(item, dtoName: 'RewardTaskDto'),
                ),
              )
              .toList(growable: false),
    );
  }

  List<RewardTask> toDomain() =>
      items.map((item) => item.toDomain()).toList(growable: false);
}

class RewardTaskDto {
  const RewardTaskDto({
    required this.claimed,
    required this.completed,
    required this.conditionText,
    required this.cycleType,
    required this.displayName,
    required this.progressValue,
    required this.rewardMax,
    required this.rewardMin,
    required this.rewardType,
    required this.targetValue,
    required this.taskKey,
  });

  final bool claimed;
  final bool completed;
  final String conditionText;
  final String cycleType;
  final String displayName;
  final int progressValue;
  final int rewardMax;
  final int rewardMin;
  final String rewardType;
  final int targetValue;
  final String taskKey;

  factory RewardTaskDto.fromJson(Map<String, Object?> json) => RewardTaskDto(
    claimed: JsonFieldParser.requireBool(
      json,
      'claimed',
      dtoName: 'RewardTaskDto',
    ),
    completed: JsonFieldParser.requireBool(
      json,
      'completed',
      dtoName: 'RewardTaskDto',
    ),
    conditionText: JsonFieldParser.requireString(
      json,
      'conditionText',
      dtoName: 'RewardTaskDto',
    ),
    cycleType: JsonFieldParser.requireString(
      json,
      'cycleType',
      dtoName: 'RewardTaskDto',
    ),
    displayName: JsonFieldParser.requireString(
      json,
      'displayName',
      dtoName: 'RewardTaskDto',
    ),
    progressValue: JsonFieldParser.requireInt(
      json,
      'progressValue',
      dtoName: 'RewardTaskDto',
    ),
    rewardMax: JsonFieldParser.requireInt(
      json,
      'rewardMax',
      dtoName: 'RewardTaskDto',
    ),
    rewardMin: JsonFieldParser.requireInt(
      json,
      'rewardMin',
      dtoName: 'RewardTaskDto',
    ),
    rewardType: JsonFieldParser.requireString(
      json,
      'rewardType',
      dtoName: 'RewardTaskDto',
    ),
    targetValue: JsonFieldParser.requireInt(
      json,
      'targetValue',
      dtoName: 'RewardTaskDto',
    ),
    taskKey: JsonFieldParser.requireString(
      json,
      'taskKey',
      dtoName: 'RewardTaskDto',
    ),
  );

  RewardTask toDomain() => RewardTask(
    claimed: claimed,
    completed: completed,
    conditionText: conditionText,
    cycleType: cycleType,
    displayName: displayName,
    progressValue: progressValue,
    rewardMax: rewardMax,
    rewardMin: rewardMin,
    rewardType: rewardType,
    targetValue: targetValue,
    taskKey: taskKey,
  );
}
