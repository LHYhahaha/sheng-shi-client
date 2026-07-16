class MemberPointDetailsPage {
  const MemberPointDetailsPage({
    required this.list,
    required this.page,
    required this.pageSize,
    required this.totalNum,
  });

  final List<MemberPointDetailRecord> list;
  final int page;
  final int pageSize;
  final int totalNum;
}

class MemberPointDetailRecord {
  const MemberPointDetailRecord({
    required this.amount,
    required this.balanceAfter,
    required this.balanceBefore,
    required this.bizType,
    required this.createdAt,
    required this.direction,
    required this.flowNo,
    required this.remark,
  });

  final int amount;
  final int balanceAfter;
  final int balanceBefore;
  final int bizType;
  final DateTime createdAt;
  final int direction;
  final String flowNo;
  final String remark;

  bool get isIncome => direction == 1;
}
