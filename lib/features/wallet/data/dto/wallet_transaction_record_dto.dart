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
  final String? memberPeriodType;  // 改为 String? 以支持枚举字符串
  final String? orderNo;
  final String? paidAt;
  final String? productType;  // 改为 String? 以支持枚举字符串

  factory WalletTransactionRecordDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    
    // 适配两种格式：
    // 1. 旧格式交易记录：id, type, amount, bonusAmount, price, currency, platform, createdAt, status, title
    // 2. 充值记录：coin, bonusCoin, amountText, currency, memberDays, memberPeriodType, orderNo, paidAt, productType, title
    
    // 处理 productType：可能是 int 或 string
    String? parsedProductType;
    final rawProductType = map['productType'];
    if (rawProductType is String) {
      // 标准化 productType 格式
      final normalized = rawProductType.toUpperCase();
      if (normalized.contains('COIN')) {
        parsedProductType = 'PRODUCT_TYPE_COIN';
      } else if (normalized.contains('MEMBER')) {
        parsedProductType = 'PRODUCT_TYPE_MEMBER';
      } else {
        parsedProductType = rawProductType;
      }
    } else if (rawProductType is int) {
      // 如果是整数，转换为对应的字符串枚举值
      switch (rawProductType) {
        case 1:
          parsedProductType = 'PRODUCT_TYPE_COIN';
        case 2:
          parsedProductType = 'PRODUCT_TYPE_MEMBER';
        default:
          parsedProductType = null;
      }
    }
    
    // 处理 memberPeriodType：可能是 int 或 string
    String? parsedMemberPeriodType;
    final rawMemberPeriodType = map['memberPeriodType'];
    if (rawMemberPeriodType is String) {
      // 标准化 memberPeriodType 格式
      final normalized = rawMemberPeriodType.toUpperCase();
      if (normalized.contains('WEEK')) {
        parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_WEEK';
      } else if (normalized.contains('MONTH')) {
        parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_MONTH';
      } else if (normalized.contains('QUARTER')) {
        parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_QUARTER';
      } else if (normalized.contains('YEAR')) {
        parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_YEAR';
      } else {
        parsedMemberPeriodType = rawMemberPeriodType;
      }
    } else if (rawMemberPeriodType is int) {
      // 如果是整数，转换为对应的字符串枚举值
      switch (rawMemberPeriodType) {
        case 1:
          parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_WEEK';
        case 2:
          parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_MONTH';
        case 3:
          parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_QUARTER';
        case 4:
          parsedMemberPeriodType = 'MEMBER_PERIOD_TYPE_YEAR';
        default:
          parsedMemberPeriodType = null;
      }
    }
    
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
      memberPeriodType: parsedMemberPeriodType,
      orderNo: _nullableString(map['orderNo']),
      paidAt: _nullableString(map['paidAt']),
      productType: parsedProductType,
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
