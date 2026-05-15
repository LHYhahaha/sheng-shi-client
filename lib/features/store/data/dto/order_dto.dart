/// 服务端创建订单后的快照。
///
/// 这个 DTO 只表示“订单已创建/进入某个状态”，不能被当成支付成功或权益已发放。
/// 真实金币/会员权益必须等平台支付结果、服务端验单和 entitlement refresh。
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

  /// 订单金额微单位。
  ///
  /// 只能用于展示/校验订单信息，不能让客户端据此自行发放权益。
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
