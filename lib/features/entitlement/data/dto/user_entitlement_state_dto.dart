class UserEntitlementStateDto {
  const UserEntitlementStateDto({
    required this.isGuest,
    required this.isMember,
    this.membershipExpiresAt,
    required this.coinBalance,
    required this.bonusBalance,
    required this.autoUnlockEnabled,
    required this.unlockedEpisodeIds,
    this.pendingOperationId,
    this.serverTime,
    this.refreshReason,
  });

  final bool isGuest;
  final bool isMember;
  final DateTime? membershipExpiresAt;
  final int coinBalance;
  final int bonusBalance;
  final bool autoUnlockEnabled;
  final List<String> unlockedEpisodeIds;
  final String? pendingOperationId;
  final DateTime? serverTime;
  final String? refreshReason;

  factory UserEntitlementStateDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return UserEntitlementStateDto(
      isGuest: map['isGuest'] == true,
      isMember: map['isMember'] == true,
      membershipExpiresAt: _date(map['membershipExpiresAt']),
      coinBalance: _int(map['coinBalance']),
      bonusBalance: _int(map['bonusBalance']),
      autoUnlockEnabled: map['autoUnlockEnabled'] == true,
      unlockedEpisodeIds: _stringList(map['unlockedEpisodeIds']),
      pendingOperationId: _nullableString(map['pendingOperationId']),
      serverTime: _date(map['serverTime']),
      refreshReason: _nullableString(map['refreshReason']),
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
