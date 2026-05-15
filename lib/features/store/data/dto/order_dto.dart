class OrderDto {
  const OrderDto({
    required this.orderId,
    required this.productId,
    required this.status,
    required this.amountMicros,
    required this.currencyCode,
    this.createdAt,
  });

  final String orderId;
  final String productId;
  final String status;
  final int amountMicros;
  final String? currencyCode;
  final DateTime? createdAt;

  factory OrderDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return OrderDto(
      orderId: _string(map['orderId']),
      productId: _string(map['productId']),
      status: _string(map['status'], fallback: 'created'),
      amountMicros: _int(map['amountMicros']),
      currencyCode: _nullableString(map['currencyCode']),
      createdAt: _date(map['createdAt']),
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

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
