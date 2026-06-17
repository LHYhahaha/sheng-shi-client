/// IAP 购买结果 DTO
///
/// 封装谷歌支付的购买凭证信息
class IapPurchaseResultDto {
  IapPurchaseResultDto({
    required this.productId,
    required this.purchaseToken,
    this.orderId,
    this.receipt,
  });

  /// 商品ID
  final String productId;

  /// 购买Token
  final String purchaseToken;

  /// 订单ID（渠道订单ID）
  final String? orderId;

  /// 原始收据
  final String? receipt;

  factory IapPurchaseResultDto.fromPurchaseDetails(dynamic purchaseDetails) {
    // 从 flutter_inapp_purchase 或 in_app_purchase 的 PurchaseDetails 提取信息
    return IapPurchaseResultDto(
      productId: purchaseDetails.productID ?? '',
      purchaseToken: purchaseDetails.verificationData?.serverVerificationData ?? '',
      orderId: purchaseDetails.purchaseID,
      receipt: purchaseDetails.verificationData?.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'purchaseToken': purchaseToken,
      if (orderId != null) 'orderId': orderId,
      if (receipt != null) 'receipt': receipt,
    };
  }
}
