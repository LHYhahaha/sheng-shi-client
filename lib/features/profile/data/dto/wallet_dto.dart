class WalletDto {
  const WalletDto({
    required this.userId,
    required this.coin,
    required this.bonusCoin,
    required this.totalCoin,
  });

  final int userId;
  final int coin;
  final int bonusCoin;
  final int totalCoin;

  factory WalletDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletDto(
      userId: _int(map['userId']),
      coin: _int(map['coin']),
      bonusCoin: _int(map['bonusCoin']),
      totalCoin: _int(map['totalCoin']),
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}
