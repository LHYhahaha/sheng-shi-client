/// 支付订单领域模型
///
/// 对应 /api/payment/order/create 接口返回的订单数据
class PaymentOrder {
  const PaymentOrder({
    required this.amountMicros,
    required this.channelProductId,
    required this.currency,
    required this.expireAt,
    required this.orderNo,
    this.clientOrderNo, // 客户端订单号（可选）
    required this.orderStatus,
    required this.orderTitle,
    required this.payChannel,
    required this.priceText,
    required this.productId,
    required this.productType,
    this.userId,
  });

  /// 微单位金额
  final int amountMicros;

  /// 渠道商品ID
  final String channelProductId;

  /// 币种
  final String currency;

  /// 过期时间（时间戳）
  final int expireAt;

  /// 服务端订单号
  final String orderNo;

  /// 客户端订单号（格式：userId_timestamp_random6）
  final String? clientOrderNo;

  /// 订单状态
  ///
  /// 字符串形式，如 "ORDER_STATUS_PENDING", "ORDER_STATUS_PAID" 等
  final String orderStatus;

  /// 订单标题（可选）
  ///
  /// 可能为空字符串或null
  final String? orderTitle;

  /// 支付渠道
  ///
  /// 字符串形式，如 "PAY_CHANNEL_GOOGLE", "PAY_CHANNEL_APPLE" 等
  final String payChannel;

  /// 展示价格
  final String priceText;

  /// 商品ID
  final int productId;

  /// 商品类型
  ///
  /// 字符串形式，如 "PRODUCT_TYPE_COIN", "PRODUCT_TYPE_MEMBERSHIP"
  final String productType;

  /// 用户ID
  final int? userId;

  PaymentOrder copyWith({
    int? amountMicros,
    String? channelProductId,
    String? currency,
    int? expireAt,
    String? orderNo,
    String? clientOrderNo,
    String? orderStatus,
    String? orderTitle,
    String? payChannel,
    String? priceText,
    int? productId,
    String? productType,
    int? userId,
  }) {
    return PaymentOrder(
      amountMicros: amountMicros ?? this.amountMicros,
      channelProductId: channelProductId ?? this.channelProductId,
      currency: currency ?? this.currency,
      expireAt: expireAt ?? this.expireAt,
      orderNo: orderNo ?? this.orderNo,
      clientOrderNo: clientOrderNo ?? this.clientOrderNo,
      orderStatus: orderStatus ?? this.orderStatus,
      orderTitle: orderTitle ?? this.orderTitle,
      payChannel: payChannel ?? this.payChannel,
      priceText: priceText ?? this.priceText,
      productId: productId ?? this.productId,
      productType: productType ?? this.productType,
      userId: userId ?? this.userId,
    );
  }

  /// 是否为金币商品
  bool get isCoinProduct => productType == 'PRODUCT_TYPE_COIN';

  /// 是否为会员商品
  bool get isMembershipProduct => productType == 'PRODUCT_TYPE_MEMBERSHIP';
}
