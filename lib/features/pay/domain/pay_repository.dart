import '../domain/payment_order.dart';
import '../data/dto/payment_order_verify_response_dto.dart';

abstract interface class PayRepository {
  /// 创建支付订单（通用接口）
  ///
  /// 所有下单都经过这个接口，支持金币商品和会员商品
  /// 如果传入 [userId]，会自动生成格式为 "userId_timestamp_random" 的 clientOrderNo
  Future<PaymentOrder> createPaymentOrder({
    required int productId,
    required int productType,
    String? clientOrderNo,
    int? episodeId,
    int? payChannel,
    String? scene,
    int? shortId,
  });

  /// 验证谷歌支付订单（通用接口）
  ///
  /// 支付成功后，将谷歌返回的凭证信息发送到服务端验证
  /// 返回验证结果，包含订单状态和订单号
  Future<PaymentOrderVerifyResponseDto> verifyGooglePayment({
    required String orderNo,
    required String channelProductId,
    required String packageName,
    required int productType,
    required String purchaseToken,
    String? channelOrderId,
    String? rawReceipt,
  });
}
