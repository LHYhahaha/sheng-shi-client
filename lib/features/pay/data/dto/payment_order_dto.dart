import 'package:drama_client/core/network/json_field_parser.dart';

import '../../domain/payment_order.dart';

/// 支付订单DTO
///
/// 对应 /api/payment/order/create 接口返回的 data 对象
class PaymentOrderDto {
  const PaymentOrderDto({
    required this.amountMicros,
    required this.channelProductId,
    required this.currency,
    required this.expireAt,
    required this.orderNo,
    this.clientOrderNo, // 可选参数
    required this.orderStatus,
    required this.orderTitle,
    required this.payChannel,
    required this.priceText,
    required this.productId,
    required this.productType,
    this.userId,
  });

  /// 微单位金额（必需）
  final int amountMicros;

  /// 渠道商品ID（必需）
  final String channelProductId;

  /// 币种（必需）
  final String currency;

  /// 过期时间（必需）
  final int expireAt;

  /// 订单号（必需）
  final String orderNo;

  /// 客户端订单号（可选）
  /// 格式：userId_timestamp_random6
  final String? clientOrderNo;

  /// 订单状态（必需）
  ///
  /// 服务端返回的是字符串，如 "ORDER_STATUS_PENDING"
  final String orderStatus;

  /// 订单标题（可选）
  ///
  /// 可能为空字符串
  final String? orderTitle;

  /// 支付渠道（必需）
  ///
  /// 服务端返回的是字符串，如 "PAY_CHANNEL_GOOGLE"
  final String payChannel;

  /// 展示价格（必需）
  final String priceText;

  /// 商品ID（必需）
  final int productId;

  /// 商品类型（必需）
  ///
  /// 服务端返回的是字符串，如 "PRODUCT_TYPE_COIN", "PRODUCT_TYPE_MEMBERSHIP"
  final String productType;

  /// 用户ID（必需）
  final int? userId;

  factory PaymentOrderDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'PaymentOrderDto');
    const dtoName = 'PaymentOrderDto';

    return PaymentOrderDto(
      amountMicros: JsonFieldParser.requireInt(
        map,
        'amountMicros',
        dtoName: dtoName,
      ),
      channelProductId: JsonFieldParser.requireString(
        map,
        'channelProductId',
        dtoName: dtoName,
      ),
      currency: JsonFieldParser.requireString(
        map,
        'currency',
        dtoName: dtoName,
      ),
      expireAt: JsonFieldParser.requireInt(map, 'expireAt', dtoName: dtoName),
      orderNo: JsonFieldParser.requireString(map, 'orderNo', dtoName: dtoName),
      clientOrderNo: JsonFieldParser.optionalString(map, 'clientOrderNo'),
      orderStatus: JsonFieldParser.requireString(
        map,
        'orderStatus',
        dtoName: dtoName,
      ),
      orderTitle: JsonFieldParser.optionalString(map, 'orderTitle'),
      payChannel: JsonFieldParser.requireString(
        map,
        'payChannel',
        dtoName: dtoName,
      ),
      priceText: JsonFieldParser.requireString(
        map,
        'priceText',
        dtoName: dtoName,
      ),
      productId: JsonFieldParser.requireInt(map, 'productId', dtoName: dtoName),
      productType: JsonFieldParser.requireString(
        map,
        'productType',
        dtoName: dtoName,
      ),
      userId: JsonFieldParser.optionalInt(map, 'userId'),
    );
  }

  /// 将DTO转换为领域模型
  PaymentOrder toDomain() {
    return PaymentOrder(
      amountMicros: amountMicros,
      channelProductId: channelProductId,
      currency: currency,
      expireAt: expireAt,
      orderNo: orderNo,
      clientOrderNo: clientOrderNo,
      orderStatus: orderStatus,
      orderTitle: orderTitle,
      payChannel: payChannel,
      priceText: priceText,
      productId: productId,
      productType: productType,
      userId: userId,
    );
  }
}
