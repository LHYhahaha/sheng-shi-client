import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/pay_channel.dart';
import '../domain/pay_repository.dart';
import '../domain/payment_method_options.dart';
import '../domain/payment_order.dart';
import 'iap_purchase_service.dart';

/// 支付入口的统一决策结果。
enum PaymentEntryAction { directGoogle, showCashier }

/// Google IAP 流程的终态。
enum GooglePurchaseOutcome { success, cancelled, pending }

/// Google IAP 执行阶段，调用方将其映射为各页面的本地状态。
enum GooglePurchasePhase { waitingPayment, verifying }

/// 统一支付方式判定和 Google IAP 执行，页面不再自行判断取消、验单与完成购买。
class PaymentPurchaseCoordinator {
  const PaymentPurchaseCoordinator({required PayRepository payRepository})
    : _payRepository = payRepository;

  final PayRepository _payRepository;

  Future<PaymentEntryAction> resolveEntry({
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
    final options = await _payRepository.getPaymentOrderOptions(
      countryCode: countryCode,
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: episodeNo,
      osType: osType,
      payScene: payScene,
      productId: productId,
      productType: productType,
      scene: scene,
    );
    return _isGoogleOnly(options)
        ? PaymentEntryAction.directGoogle
        : PaymentEntryAction.showCashier;
  }

  /// 执行一次完整 Google IAP：拉起购买、处理取消/待处理、服务端验单与确认消费。
  Future<GooglePurchaseOutcome> executeGooglePurchase({
    required IapPurchaseService iapService,
    required PaymentOrder order,
    required ProductDetails product,
    required bool isConsumable,
    required int productType,
    required String packageName,
    String? offerToken,
    void Function(GooglePurchasePhase phase)? onPhase,
  }) async {
    StreamSubscription<PurchaseDetails>? purchaseSubscription;
    StreamSubscription<Object>? errorSubscription;
    try {
      final completer = Completer<PurchaseDetails?>();
      purchaseSubscription = iapService.purchaseStream.listen((details) {
        final isCurrentProduct = details.productID == product.id;
        final isPurchaseError = details.status == PurchaseStatus.error;
        final isCancellation =
            details.status.name == 'canceled' ||
            (details.status == PurchaseStatus.error &&
                _isUserCancelledPurchase(details));
        if ((isCurrentProduct || isPurchaseError || isCancellation) &&
            !completer.isCompleted) {
          completer.complete(details);
        }
      });
      errorSubscription = iapService.purchaseErrorStream.listen((error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      onPhase?.call(GooglePurchasePhase.waitingPayment);
      final started = await iapService.buyProduct(
        product: product,
        isConsumable: isConsumable,
        offerToken: offerToken,
        applicationUserName: iapService.buildOrderApplicationUserName(
          orderNo: order.orderNo,
          clientOrderNo: order.clientOrderNo,
        ),
      );
      if (!started) {
        throw StateError('Failed to launch Google Play payment.');
      }

      final details = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => null,
      );
      if (details == null ||
          details.status.name == 'canceled' ||
          (details.status == PurchaseStatus.error &&
              _isUserCancelledPurchase(details))) {
        return GooglePurchaseOutcome.cancelled;
      }
      if (details.status == PurchaseStatus.pending) {
        return GooglePurchaseOutcome.pending;
      }
      if (details.status == PurchaseStatus.error) {
        throw StateError('Google Play payment failed: ${details.error}');
      }
      if (details.status != PurchaseStatus.purchased &&
          details.status != PurchaseStatus.restored) {
        throw StateError('Unsupported purchase status: ${details.status}');
      }

      onPhase?.call(GooglePurchasePhase.verifying);
      final verifyResult = await _payRepository.verifyGooglePayment(
        orderNo: order.orderNo,
        channelProductId: details.productID,
        packageName: packageName,
        productType: productType,
        purchaseToken: details.verificationData.serverVerificationData,
        channelOrderId: details.purchaseID,
        rawReceipt: details.verificationData.source,
      );
      if (verifyResult.orderStatus != 'ORDER_STATUS_SUCCESS') {
        throw StateError(
          'Payment verification returned ${verifyResult.orderStatus}',
        );
      }
      if (details.pendingCompletePurchase) {
        await iapService.completePurchase(details);
      }
      return GooglePurchaseOutcome.success;
    } finally {
      await purchaseSubscription?.cancel();
      await errorSubscription?.cancel();
    }
  }

  bool _isGoogleOnly(PaymentMethodOptions options) =>
      options.options.length == 1 &&
      PayChannel.isGoogle(options.options.single.payChannel);

  static bool _isUserCancelledPurchase(PurchaseDetails details) {
    final code = details.error?.code.toLowerCase();
    final message = details.error?.message.toLowerCase();
    return code?.contains('cancel') == true ||
        code?.contains('user') == true ||
        message?.contains('cancel') == true ||
        message?.contains('user') == true;
  }
}
