import 'package:drama_client/core/network/json_field_parser.dart';

/// 支付订单验证响应 DTO
///
/// 对应 /api/payment/google/verify 接口返回的 data 对象
class PaymentOrderVerifyResponseDto {
  PaymentOrderVerifyResponseDto({
    required this.orderNo,
    required this.orderStatus,
    this.channelOrderId,
    this.paidAt,
    this.coin,
    this.bonusCoin,
    this.isMember,
    this.productType,
  });

  /// 订单号
  final String orderNo;

  /// 订单状态
  ///
  /// 如："ORDER_STATUS_SUCCESS", "ORDER_STATUS_PENDING", "ORDER_STATUS_FAILED"
  final String orderStatus;

  /// 渠道订单ID
  final String? channelOrderId;

  /// 支付时间
  final DateTime? paidAt;

  /// 金币余额
  final int? coin;

  /// 赠送金币余额
  final int? bonusCoin;

  /// 是否为会员
  final bool? isMember;

  /// 商品类型
  final String? productType;

  factory PaymentOrderVerifyResponseDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'PaymentOrderVerifyResponseDto',
    );
    return PaymentOrderVerifyResponseDto(
      orderNo: JsonFieldParser.requireString(
        map,
        'orderNo',
        dtoName: 'PaymentOrderVerifyResponseDto',
      ),
      orderStatus: JsonFieldParser.requireString(
        map,
        'orderStatus',
        dtoName: 'PaymentOrderVerifyResponseDto',
      ),
      channelOrderId: JsonFieldParser.optionalString(map, 'channelOrderId'),
      paidAt: map['paidAt'] != null
          ? JsonFieldParser.requireDateTime(
              map,
              'paidAt',
              dtoName: 'PaymentOrderVerifyResponseDto',
            )
          : null,
      coin: JsonFieldParser.optionalInt(map, 'coin'),
      bonusCoin: JsonFieldParser.optionalInt(map, 'bonusCoin'),
      isMember: JsonFieldParser.optionalBool(map, 'isMember'),
      productType: JsonFieldParser.optionalString(map, 'productType'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderNo': orderNo,
      'orderStatus': orderStatus,
      if (channelOrderId != null) 'channelOrderId': channelOrderId,
      if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
      if (coin != null) 'coin': coin,
      if (bonusCoin != null) 'bonusCoin': bonusCoin,
      if (isMember != null) 'isMember': isMember,
      if (productType != null) 'productType': productType,
    };
  }
}
