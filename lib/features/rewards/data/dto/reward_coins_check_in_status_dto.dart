import '../../../../core/network/json_field_parser.dart';
import '../../domain/reward_coins_check_in_status.dart';

class RewardCoinsCheckInStatusDto {
  const RewardCoinsCheckInStatusDto({
    required this.checkedDays,
    required this.checkedToday,
    required this.currentDay,
    required this.days,
  });

  final int checkedDays;
  final bool checkedToday;
  final int currentDay;
  final List<RewardCoinsCheckInDayDto> days;

  factory RewardCoinsCheckInStatusDto.fromJson(Map<String, Object?> json) {
    return RewardCoinsCheckInStatusDto(
      checkedDays: JsonFieldParser.requireInt(
        json,
        'checkedDays',
        dtoName: 'RewardCoinsCheckInStatusDto',
      ),
      checkedToday: JsonFieldParser.requireBool(
        json,
        'checkedToday',
        dtoName: 'RewardCoinsCheckInStatusDto',
      ),
      currentDay: JsonFieldParser.requireInt(
        json,
        'currentDay',
        dtoName: 'RewardCoinsCheckInStatusDto',
      ),
      days:
          JsonFieldParser.requireList(
                json['days'],
                dtoName: 'RewardCoinsCheckInStatusDto',
                field: 'days',
              )
              .map(
                (item) => RewardCoinsCheckInDayDto.fromJson(
                  JsonFieldParser.requireMap(
                    item,
                    dtoName: 'RewardCoinsCheckInDayDto',
                  ),
                ),
              )
              .toList(growable: false),
    );
  }

  RewardCoinsCheckInStatus toDomain() => RewardCoinsCheckInStatus(
    checkedDays: checkedDays,
    checkedToday: checkedToday,
    currentDay: currentDay,
    days: days.map((item) => item.toDomain()).toList(growable: false),
  );
}

class RewardCoinsCheckInDayDto {
  const RewardCoinsCheckInDayDto({
    required this.checked,
    required this.claimable,
    required this.current,
    required this.day,
    required this.rewardCoin,
  });

  final bool checked;
  final bool claimable;
  final bool current;
  final int day;
  final String rewardCoin;

  factory RewardCoinsCheckInDayDto.fromJson(Map<String, Object?> json) {
    return RewardCoinsCheckInDayDto(
      checked: JsonFieldParser.requireBool(
        json,
        'checked',
        dtoName: 'RewardCoinsCheckInDayDto',
      ),
      claimable: JsonFieldParser.requireBool(
        json,
        'claimable',
        dtoName: 'RewardCoinsCheckInDayDto',
      ),
      current: JsonFieldParser.requireBool(
        json,
        'current',
        dtoName: 'RewardCoinsCheckInDayDto',
      ),
      day: JsonFieldParser.requireInt(
        json,
        'day',
        dtoName: 'RewardCoinsCheckInDayDto',
      ),
      rewardCoin: JsonFieldParser.requireString(
        json,
        'rewardCoin',
        dtoName: 'RewardCoinsCheckInDayDto',
      ),
    );
  }

  RewardCoinsCheckInDay toDomain() => RewardCoinsCheckInDay(
    checked: checked,
    claimable: claimable,
    current: current,
    day: day,
    rewardCoin: rewardCoin,
  );
}
