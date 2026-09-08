/// 限时试看配置，仅保留数据，后续业务逻辑按需使用。
class DramaTrial {
  const DramaTrial({
    required this.trialEnabled,
    required this.trialEpisodeNum,
    required this.trialDurationSec,
  });

  final bool trialEnabled;
  final int trialEpisodeNum;
  final int trialDurationSec;
}
