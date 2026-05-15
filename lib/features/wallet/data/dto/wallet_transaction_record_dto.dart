class WalletTransactionRecordDto {
  const WalletTransactionRecordDto({
    required this.id,
    required this.type,
    required this.amount,
    required this.bonusAmount,
    required this.price,
    required this.currency,
    required this.platform,
    required this.createdAt,
    required this.status,
    this.title,
  });

  final String id;
  final String type;
  final int amount;
  final int bonusAmount;
  final int? price;
  final String? currency;
  final String? platform;
  final DateTime? createdAt;
  final String status;
  final String? title;

  factory WalletTransactionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return WalletTransactionRecordDto(
      id: _string(map['id']),
      type: _string(map['type'], fallback: 'transaction'),
      amount: _int(map['amount']),
      bonusAmount: _int(map['bonusAmount']),
      price: _nullableInt(map['price']),
      currency: _nullableString(map['currency']),
      platform: _nullableString(map['platform']),
      createdAt: _date(map['createdAt']),
      status: _string(map['status'], fallback: 'success'),
      title: _nullableString(map['title']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
