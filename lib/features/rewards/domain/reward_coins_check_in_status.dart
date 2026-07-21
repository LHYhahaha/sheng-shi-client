class RewardCoinsCheckInStatus {
  const RewardCoinsCheckInStatus({
    required this.checkedToday,
    required this.currentDay,
    required this.days,
  });

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
