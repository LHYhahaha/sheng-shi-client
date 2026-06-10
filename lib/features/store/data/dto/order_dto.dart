import '../../../../core/network/json_field_parser.dart';

/// 服务端创建订单后的快照。
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
    final map = JsonFieldParser.requireMap(json, dtoName: 'OrderDto');
    const dtoName = 'OrderDto';
    return OrderDto(
      orderId: JsonFieldParser.requireString(map, 'orderId', dtoName: dtoName),
      productId: JsonFieldParser.requireString(
        map,
        'productId',
        dtoName: dtoName,
      ),
      status: JsonFieldParser.requireString(map, 'status', dtoName: dtoName),
      amountMicros: JsonFieldParser.requireInt(
        map,
        'amountMicros',
        dtoName: dtoName,
      ),
      currencyCode: JsonFieldParser.optionalString(map, 'currencyCode'),
      createdAt: JsonFieldParser.optionalDateTime(map, 'createdAt'),
    );
  }
}
