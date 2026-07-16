class MemberPointClaimResult {
  const MemberPointClaimResult({
    required this.claimNo,
    required this.grantedAt,
    required this.pointBalance,
    required this.rewardAmount,
    required this.status,
  });

  final String claimNo;
  final String grantedAt;
  final int pointBalance;
  final int rewardAmount;
  final String status;

  bool get isSuccess => status == 'CLAIM_STATUS_SUCCESS';
}
