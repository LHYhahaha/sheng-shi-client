class WalletRewardCoinRecordDto {
  const WalletRewardCoinRecordDto({
    required this.id,
    required this.title,
    required this.amountCoins,
    required this.expiresAt,
    required this.claimable,
    required this.claimed,
    required this.claimedAt,
  });

  final String id;
  final String title;
  final int amountCoins;
  final DateTime? expiresAt;
  final bool claimable;
  final bool claimed;
  final DateTime? claimedAt;

  factory WalletRewardCoinRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletRewardCoinRecordDto(
      id: _string(map['id']),
      title: _string(map['title']),
      amountCoins: _int(map['amountCoins']),
      expiresAt: _date(map['expiresAt']),
      claimable: _bool(map['claimable']),
      claimed: _bool(map['claimed']),
      claimedAt: _date(map['claimedAt']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

bool _bool(Object? value) => value == true;

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
