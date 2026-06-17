import 'package:drama_client/core/utils/order_no_generator.dart';

/// 支付订单创建请求DTO
///
/// 所有下单都经过这个通用的订单创建接口
class PaymentOrderCreateRequestDto {
  PaymentOrderCreateRequestDto({
    required this.productId,
    required this.productType,
    String? clientOrderNo,
    this.episodeId,
    this.payChannel,
    this.scene,
    this.shortId,
  }) : clientOrderNo = clientOrderNo ?? OrderNoGenerator.generate();

  /// 商品ID（必需）
  final int productId;

  /// 商品类型（必需）
  /// 1: 金币商品；2: 会员商品
  final int productType;

  /// 客户端订单号（自动生成）
  final String clientOrderNo;

  /// 分集ID（可选）
  final int? episodeId;

  /// 支付渠道（可选）
  /// 不传时服务端默认 Google Play
  final int? payChannel;

  /// 下单场景（可选）
  /// 例如: recharge_page、member_page
  final String? scene;

  /// 短剧ID（可选）
  final int? shortId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'productId': productId,
      'productType': productType,
      'clientOrderNo': clientOrderNo,
      if (episodeId != null) 'episodeId': episodeId,
      if (payChannel != null) 'payChannel': payChannel,
      if (scene != null) 'scene': scene,
      if (shortId != null) 'shortId': shortId,
    };
  }
}
