import '../../../../core/network/json_field_parser.dart';

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
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'UserEntitlementStateDto',
    );
    const dtoName = 'UserEntitlementStateDto';
    return UserEntitlementStateDto(
      isGuest: JsonFieldParser.requireBool(map, 'isGuest', dtoName: dtoName),
      isMember: JsonFieldParser.requireBool(map, 'isMember', dtoName: dtoName),
      membershipExpiresAt: JsonFieldParser.optionalDateTime(
        map,
        'membershipExpiresAt',
      ),
      coinBalance: JsonFieldParser.requireInt(
        map,
        'coinBalance',
        dtoName: dtoName,
      ),
      bonusBalance: JsonFieldParser.requireInt(
        map,
        'bonusBalance',
        dtoName: dtoName,
      ),
      autoUnlockEnabled: JsonFieldParser.requireBool(
        map,
        'autoUnlockEnabled',
        dtoName: dtoName,
      ),
      unlockedEpisodeIds: _stringList(map['unlockedEpisodeIds']),
      pendingOperationId: JsonFieldParser.optionalString(
        map,
        'pendingOperationId',
      ),
      serverTime: JsonFieldParser.optionalDateTime(map, 'serverTime'),
      refreshReason: JsonFieldParser.optionalString(map, 'refreshReason'),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}
