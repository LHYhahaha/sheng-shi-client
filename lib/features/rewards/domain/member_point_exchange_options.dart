class MemberPointExchangeOptions {
  const MemberPointExchangeOptions({
    required this.balance,
    required this.isMember,
    required this.list,
  });

  final int balance;
  final bool isMember;
  final List<MemberPointExchangeTier> list;
}

class MemberPointExchangeTier {
  const MemberPointExchangeTier({
    required this.canExchange,
    required this.displayName,
    required this.exchangeStatus,
    required this.memberDays,
    required this.pointCost,
    required this.priority,
    required this.status,
    required this.tierId,
  });

  final bool canExchange;
  final String displayName;
  final String exchangeStatus;
  final int memberDays;
  final int pointCost;
  final int priority;
  final int status;
  final int tierId;
}
