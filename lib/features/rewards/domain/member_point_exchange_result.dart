class MemberPointExchangeResult {
  const MemberPointExchangeResult({
    required this.exchangeNo,
    required this.memberDays,
    required this.pointBalance,
    required this.status,
  });

  final String exchangeNo;
  final int memberDays;
  final int pointBalance;
  final String status;

  bool get isSuccess => status == 'CLAIM_STATUS_SUCCESS';
}
