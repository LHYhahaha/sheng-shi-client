class RewardTask {
  const RewardTask({
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

  String get rewardText => rewardMin == rewardMax ? '+$rewardMin' : '+??';
}
