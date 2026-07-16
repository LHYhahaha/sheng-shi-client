import '../../../../core/network/json_field_parser.dart';
import '../../domain/member_point_daily_detail.dart';

class MemberPointDailyDetailDto {
  const MemberPointDailyDetailDto({
    required this.dayProgress,
    required this.memberDay,
    required this.tasks,
    required this.totalAvailablePoint,
    required this.totalPointBalance,
  });

  final List<MemberPointDayProgressDto> dayProgress;
  final int memberDay;
  final List<MemberPointTaskDto> tasks;
  final int totalAvailablePoint;
  final int totalPointBalance;

  factory MemberPointDailyDetailDto.fromJson(Map<String, Object?> json) {
    return MemberPointDailyDetailDto(
      dayProgress:
          JsonFieldParser.requireList(
                json['dayProgress'],
                dtoName: 'MemberPointDailyDetailDto',
                field: 'dayProgress',
              )
              .map(
                (item) => MemberPointDayProgressDto.fromJson(
                  JsonFieldParser.requireMap(
                    item,
                    dtoName: 'MemberPointDayProgressDto',
                  ),
                ),
              )
              .toList(growable: false),
      memberDay: JsonFieldParser.requireInt(
        json,
        'memberDay',
        dtoName: 'MemberPointDailyDetailDto',
      ),
      tasks:
          JsonFieldParser.requireList(
                json['tasks'],
                dtoName: 'MemberPointDailyDetailDto',
                field: 'tasks',
              )
              .map(
                (item) => MemberPointTaskDto.fromJson(
                  JsonFieldParser.requireMap(
                    item,
                    dtoName: 'MemberPointTaskDto',
                  ),
                ),
              )
              .toList(growable: false),
      totalAvailablePoint: JsonFieldParser.requireInt(
        json,
        'totalAvailablePoint',
        dtoName: 'MemberPointDailyDetailDto',
      ),
      totalPointBalance:
          JsonFieldParser.optionalInt(json, 'totalPointBalance') ?? 0,
    );
  }

  MemberPointDailyDetail toDomain() => MemberPointDailyDetail(
    dayProgress: dayProgress
        .map((item) => item.toDomain())
        .toList(growable: false),
    memberDay: memberDay,
    tasks: tasks.map((item) => item.toDomain()).toList(growable: false),
    totalAvailablePoint: totalAvailablePoint,
    totalPointBalance: totalPointBalance,
  );
}

class MemberPointDayProgressDto {
  const MemberPointDayProgressDto({
    required this.claimedPoint,
    required this.current,
    required this.index,
    required this.memberDay,
    required this.totalPoint,
  });

  final int claimedPoint;
  final bool current;
  final int index;
  final int memberDay;
  final int totalPoint;

  factory MemberPointDayProgressDto.fromJson(Map<String, Object?> json) {
    return MemberPointDayProgressDto(
      claimedPoint: JsonFieldParser.requireInt(
        json,
        'claimedPoint',
        dtoName: 'MemberPointDayProgressDto',
      ),
      current: JsonFieldParser.requireBool(
        json,
        'current',
        dtoName: 'MemberPointDayProgressDto',
      ),
      index: JsonFieldParser.requireInt(
        json,
        'index',
        dtoName: 'MemberPointDayProgressDto',
      ),
      memberDay: JsonFieldParser.requireInt(
        json,
        'memberDay',
        dtoName: 'MemberPointDayProgressDto',
      ),
      totalPoint: JsonFieldParser.requireInt(
        json,
        'totalPoint',
        dtoName: 'MemberPointDayProgressDto',
      ),
    );
  }

  MemberPointDayProgress toDomain() => MemberPointDayProgress(
    claimedPoint: claimedPoint,
    current: current,
    index: index,
    memberDay: memberDay,
    totalPoint: totalPoint,
  );
}

class MemberPointTaskDto {
  const MemberPointTaskDto({
    required this.canClaim,
    required this.claimed,
    required this.claimedRewardAmount,
    required this.completed,
    required this.conditionText,
    required this.displayName,
    required this.progressValue,
    required this.rewardMax,
    required this.rewardMin,
    required this.targetValue,
    required this.taskKey,
  });

  final bool canClaim;
  final bool claimed;
  final int claimedRewardAmount;
  final bool completed;
  final String conditionText;
  final String displayName;
  final int progressValue;
  final int rewardMax;
  final int rewardMin;
  final int targetValue;
  final String taskKey;

  factory MemberPointTaskDto.fromJson(Map<String, Object?> json) {
    return MemberPointTaskDto(
      canClaim: JsonFieldParser.requireBool(
        json,
        'canClaim',
        dtoName: 'MemberPointTaskDto',
      ),
      claimed: JsonFieldParser.requireBool(
        json,
        'claimed',
        dtoName: 'MemberPointTaskDto',
      ),
      claimedRewardAmount:
          JsonFieldParser.optionalInt(json, 'claimedRewardAmount') ?? 0,
      completed: JsonFieldParser.requireBool(
        json,
        'completed',
        dtoName: 'MemberPointTaskDto',
      ),
      conditionText: JsonFieldParser.requireString(
        json,
        'conditionText',
        dtoName: 'MemberPointTaskDto',
      ),
      displayName: JsonFieldParser.requireString(
        json,
        'displayName',
        dtoName: 'MemberPointTaskDto',
      ),
      progressValue: JsonFieldParser.requireInt(
        json,
        'progressValue',
        dtoName: 'MemberPointTaskDto',
      ),
      rewardMax: JsonFieldParser.requireInt(
        json,
        'rewardMax',
        dtoName: 'MemberPointTaskDto',
      ),
      rewardMin: JsonFieldParser.requireInt(
        json,
        'rewardMin',
        dtoName: 'MemberPointTaskDto',
      ),
      targetValue: JsonFieldParser.requireInt(
        json,
        'targetValue',
        dtoName: 'MemberPointTaskDto',
      ),
      taskKey: JsonFieldParser.requireString(
        json,
        'taskKey',
        dtoName: 'MemberPointTaskDto',
      ),
    );
  }

  MemberPointTask toDomain() => MemberPointTask(
    canClaim: canClaim,
    claimed: claimed,
    claimedRewardAmount: claimedRewardAmount,
    completed: completed,
    conditionText: conditionText,
    displayName: displayName,
    progressValue: progressValue,
    rewardMax: rewardMax,
    rewardMin: rewardMin,
    targetValue: targetValue,
    taskKey: taskKey,
  );
}
