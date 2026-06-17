import 'package:drama_client/core/network/json_field_parser.dart';
import 'iap_purchase_result_dto.dart';

/// 支付订单验证请求 DTO
///
/// 用于向服务端验证谷歌支付订单
class PaymentOrderVerifyRequestDto {
  PaymentOrderVerifyRequestDto({
    required this.orderNo,
    required this.channelOrderId,
    required this.channelProductId,
    required this.packageName,
    required this.productType,
    required this.purchaseToken,
    this.rawReceipt,
  });

  /// 订单号（创建订单时返回）
  final String orderNo;

  /// 渠道订单ID（谷歌支付后返回，可选）
  final String? channelOrderId;

  /// 渠道商品ID（谷歌支付后返回）
  final String channelProductId;

  /// 包名
  final String packageName;

  /// 商品类型（1=金币，2=会员）
  final int productType;

  /// 购买Token（谷歌支付后返回）
  final String purchaseToken;

  /// 原始票据（可选）
  final String? rawReceipt;

  Map<String, dynamic> toJson() {
    return {
      'orderNo': orderNo,
      if (channelOrderId != null) 'channelOrderId': channelOrderId,
      'channelProductId': channelProductId,
      'packageName': packageName,
      'productType': productType,
      'purchaseToken': purchaseToken,
      if (rawReceipt != null) 'rawReceipt': rawReceipt,
    };
  }

  /// 从 IAP 购买结果创建 DTO
  factory PaymentOrderVerifyRequestDto.fromIapPurchase({
    required String orderNo,
    required int productType,
    required String packageName,
    required IapPurchaseResultDto purchase,
  }) {
    return PaymentOrderVerifyRequestDto(
      orderNo: orderNo,
      channelOrderId: purchase.orderId,
      channelProductId: purchase.productId,
      packageName: packageName,
      productType: productType,
      purchaseToken: purchase.purchaseToken,
      rawReceipt: purchase.receipt,
    );
  }
}
