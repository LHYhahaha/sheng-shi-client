class WalletTransactionRecordDto {
  const WalletTransactionRecordDto({
    required this.id,
    required this.type,
    // required this.amount,
    required this.bonusAmount,
    required this.coinAmount,
    required this.price,
    required this.currency,
    required this.platform,
    required this.createdAt,
    required this.status,
    this.title,
    this.amountText,
    this.memberDays,
    this.memberPeriodType,
    this.orderNo,
    this.paidAt,
    this.productType,
  });

  final String id;
  final String type;
  final int coinAmount;
  // final int amount;
  final int bonusAmount;
  final int? price;
  final String? currency;
  final String? platform;
  final DateTime? createdAt;
  final String status;
  final String? title;
  
  // 充值记录特有字段
  final String? amountText;
  final int? memberDays;
  final int? memberPeriodType;
  final String? orderNo;
  final String? paidAt;
  final int? productType;

  factory WalletTransactionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    
    // 适配两种格式：
    // 1. 旧格式交易记录：id, type, amount, bonusAmount, price, currency, platform, createdAt, status, title
    // 2. 充值记录：coin, bonusCoin, amountText, currency, memberDays, memberPeriodType, orderNo, paidAt, productType, title
    
    return WalletTransactionRecordDto(
      id: _string(map['orderNo']),
      type: _string(map['type'], fallback: 'transaction'),
      // amount: _int(map['amount'] ?? map['coin']),
      coinAmount: _int(map['coin']),
      bonusAmount: _int(map['bonusAmount'] ?? map['bonusCoin']),
      price: _nullableInt(map['price']),
      currency: _nullableString(map['currency']),
      platform: _nullableString(map['platform']),
      createdAt: _date(map['createdAt'] ?? map['paidAt']),
      status: _string(map['status'], fallback: 'success'),
      title: _nullableString(map['title']),
      amountText: _nullableString(map['amountText']),
      memberDays: _nullableInt(map['memberDays']),
      memberPeriodType: _nullableInt(map['memberPeriodType']),
      orderNo: _nullableString(map['orderNo']),
      paidAt: _nullableString(map['paidAt']),
      productType: _nullableInt(map['productType']),
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
  if (value is String) return int.tryParse(value) ?? fallback;
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
