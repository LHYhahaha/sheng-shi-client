class EpisodeAccessDecisionDto {
  const EpisodeAccessDecisionDto({
    required this.type,
    required this.dramaId,
    required this.episodeId,
    required this.itemId,
    required this.unlockType,
    this.price,
    this.balance,
    this.reason,
    this.operationId,
  });

  final String type;
  final String dramaId;
  final String episodeId;
  final String itemId;
  final String unlockType;
  final int? price;
  final int? balance;
  final String? reason;
  final String? operationId;

  factory EpisodeAccessDecisionDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return EpisodeAccessDecisionDto(
      type: _string(map['type'], fallback: 'waitUnlock'),
      dramaId: _string(map['dramaId']),
      episodeId: _string(map['episodeId']),
      itemId: _string(map['itemId']),
      unlockType: _string(map['unlockType'], fallback: 'coins'),
      price: _nullableInt(map['price']),
      balance: _nullableInt(map['balance']),
      reason: _nullableString(map['reason']),
      operationId: _nullableString(map['operationId']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
