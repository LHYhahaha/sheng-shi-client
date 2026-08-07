class RewardCoinsCheckInStatus {
  const RewardCoinsCheckInStatus({
    required this.checkedDays,
    required this.checkedToday,
    required this.currentDay,
    required this.days,
  });

  /// 当前签到周期内已经完成签到的天数。
  final int checkedDays;
  final bool checkedToday;
  final int currentDay;
  final List<RewardCoinsCheckInDay> days;
}

class RewardCoinsCheckInDay {
  const RewardCoinsCheckInDay({
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
}
