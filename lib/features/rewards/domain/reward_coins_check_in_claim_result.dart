class RewardCoinsCheckInClaimResult {
  const RewardCoinsCheckInClaimResult({
    required this.balance,
    required this.claimNo,
    required this.grantedAt,
    required this.rewardAmount,
    required this.rewardType,
    required this.status,
  });

  final int balance;
  final String claimNo;
  final String grantedAt;
  final int rewardAmount;
  final String rewardType;
  final String status;

  bool get isSuccess => status == 'CLAIM_STATUS_SUCCESS';
}
