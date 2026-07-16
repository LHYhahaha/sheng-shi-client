class MemberPointDailyDetail {
  const MemberPointDailyDetail({
    required this.dayProgress,
    required this.memberDay,
    required this.tasks,
    required this.totalAvailablePoint,
    required this.totalPointBalance,
  });

  final List<MemberPointDayProgress> dayProgress;
  final int memberDay;
  final List<MemberPointTask> tasks;
  final int totalAvailablePoint;
  final int totalPointBalance;
}

class MemberPointDayProgress {
  const MemberPointDayProgress({
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
}

class MemberPointTask {
  const MemberPointTask({
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
}
