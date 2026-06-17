import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:drama_client/features/pay/domain/payment_order.dart';
import 'package:drama_client/features/pay/data/dto/payment_order_verify_response_dto.dart';

/// 支付调试数据 Provider
///
/// 用于存储支付调试信息，方便调试页面显示
final paymentDebugDataProvider =
    NotifierProvider<PaymentDebugDataNotifier, PaymentDebugData?>(
  PaymentDebugDataNotifier.new,
);

/// 支付调试数据 Notifier
class PaymentDebugDataNotifier extends Notifier<PaymentDebugData?> {
  @override
  PaymentDebugData? build() => null;

  /// 设置调试数据
  void setData(PaymentDebugData data) {
    state = data;
  }

  /// 清除调试数据
  void clear() {
    state = null;
  }
}

/// 支付调试数据
class PaymentDebugData {
  const PaymentDebugData({
    this.paymentOrder,
    this.purchaseDetails,
    this.verifyResponse,
    this.error,
  });

  /// 订单创建响应
  final PaymentOrder? paymentOrder;

  /// IAP购买回调详情
  final PurchaseDetails? purchaseDetails;

  /// 服务端验单响应
  final PaymentOrderVerifyResponseDto? verifyResponse;

  /// 错误信息
  final Object? error;

  /// 复制并添加订单信息
  PaymentDebugData copyWithOrder(PaymentOrder order) {
    return PaymentDebugData(
      paymentOrder: order,
      purchaseDetails: purchaseDetails,
      verifyResponse: verifyResponse,
      error: error,
    );
  }

  /// 复制并添加购买详情
  PaymentDebugData copyWithPurchase(PurchaseDetails details) {
    return PaymentDebugData(
      paymentOrder: paymentOrder,
      purchaseDetails: details,
      verifyResponse: verifyResponse,
      error: error,
    );
  }

  /// 复制并添加验单响应
  PaymentDebugData copyWithVerifyResponse(
      PaymentOrderVerifyResponseDto response) {
    return PaymentDebugData(
      paymentOrder: paymentOrder,
      purchaseDetails: purchaseDetails,
      verifyResponse: response,
      error: error,
    );
  }

  /// 复制并添加错误信息
  PaymentDebugData copyWithError(Object error) {
    return PaymentDebugData(
      paymentOrder: paymentOrder,
      purchaseDetails: purchaseDetails,
      verifyResponse: verifyResponse,
      error: error,
    );
  }
}
