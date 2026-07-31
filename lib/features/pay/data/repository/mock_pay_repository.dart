import '../../domain/pay_repository.dart';
import '../../domain/payment_method_options.dart';
import '../../domain/payment_order.dart';
import '../dto/payment_order_verify_response_dto.dart';

/// 模拟支付仓库实现（用于测试）
class MockPayRepository implements PayRepository {
  @override
  Future<PaymentMethodOptions> getPaymentOrderOptions({
    required int osType,
    required int payScene,
    required int productId,
    required int productType,
    String? countryCode,
    int? dramaId,
    int? episodeId,
    int? episodeNo,
    String? scene,
  }) async {
    return PaymentMethodOptions(
      countryCode: countryCode ?? 'US',
      defaultMethodCode: 'google_play',
      directPay: true,
      options: const [
        PaymentMethodOption(
          actionType: 'GOOGLE_PLAY',
          actionUrl: '',
          amountMicros: 9990000,
          channelProductId: 'com.example.product',
          currency: 'USD',
          methodCode: 'google_play',
          methodName: 'Google Play',
          originalPriceText: '',
          payChannel: 'PAY_CHANNEL_GOOGLE',
          priceSource: 1,
          priceText: r'$9.99',
          productDependency: '',
          promotionAmountMicros: 0,
          promotionPriceText: '',
          promotionText: '',
          sort: 0,
          supportRefund: true,
        ),
      ],
      osType: osType == 1 ? 'CLIENT_OS_TYPE_IOS' : 'CLIENT_OS_TYPE_ANDROID',
      payScene: payScene == 1
          ? 'PAYMENT_SCENE_ONE_TIME'
          : 'PAYMENT_SCENE_SUBSCRIPTION',
      productId: productId,
      productType: productType == 1
          ? 'PRODUCT_TYPE_COIN'
          : 'PRODUCT_TYPE_MEMBER',
      showCashier: false,
    );
  }

  @override
  Future<PaymentOrder> createPaymentOrder({
    required int productId,
    required int productType,
    String? clientOrderNo,
    int? episodeId,
    int? payChannel,
    String? scene,
    int? shortId,
  }) async {
    // 模拟网络延迟
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // 将 int productType 转换为 String
    // 1: 金币商品 -> PRODUCT_TYPE_COIN
    // 2: 会员商品 -> PRODUCT_TYPE_MEMBERSHIP
    final productTypeString = productType == 1
        ? 'PRODUCT_TYPE_COIN'
        : 'PRODUCT_TYPE_MEMBERSHIP';

    // 返回模拟支付订单
    return PaymentOrder(
      amountMicros: 9990000,
      channelProductId: 'com.example.product',
      currency: 'USD',
      expireAt: DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch,
      orderNo: 'mock_order_${DateTime.now().millisecondsSinceEpoch}',
      clientOrderNo: clientOrderNo ?? 'mock_client_order',
      orderStatus: "0",
      orderTitle: 'Mock Order',
      payChannel: "1",
      priceText: '\$9.99',
      productId: productId,
      productType: productTypeString,
    );
  }

  @override
  Future<PaymentOrderVerifyResponseDto> verifyGooglePayment({
    required String orderNo,
    required String channelProductId,
    required String packageName,
    required int productType,
    required String purchaseToken,
    String? channelOrderId,
    String? rawReceipt,
  }) async {
    // 模拟网络延迟
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // 返回模拟验证响应
    return PaymentOrderVerifyResponseDto(
      orderNo: orderNo,
      orderStatus: 'ORDER_STATUS_SUCCESS',
      channelOrderId: channelOrderId ?? 'mock_channel_order',
      paidAt: DateTime.now(),
    );
  }
}
