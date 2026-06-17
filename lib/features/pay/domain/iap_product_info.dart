import 'package:in_app_purchase/in_app_purchase.dart';

/// IAP 商品信息（包含促销信息）
///
/// 在 [IapPriceService] 查询商品时，自动提取促销价、原价、offerToken 等信息，
/// 避免在业务层重复调用提取逻辑。
class IapProductInfo {
  const IapProductInfo({
    required this.productDetails,
    this.hasPromo = false,
    this.promoPrice,
    this.promoPriceMicros,
    this.promoPeriod,
    this.regularPrice,
    this.regularPriceMicros,
    this.regularPeriod,
    this.offerToken,
    this.basePlanId,
    this.offerId,
  });

  /// 原始商品详情
  final ProductDetails productDetails;

  /// 是否有促销/试用
  final bool hasPromo;

  /// 促销价（格式化，如 "$0.99"）
  final String? promoPrice;

  /// 促销价（微单位）
  final int? promoPriceMicros;

  /// 促销周期（ISO 8601，如 "P1W"）
  final String? promoPeriod;

  /// 续费原价（格式化，如 "$9.99"）
  final String? regularPrice;

  /// 续费原价（微单位）
  final int? regularPriceMicros;

  /// 续费周期（ISO 8601，如 "P1W"）
  final String? regularPeriod;

  /// 购买时需要传入的 offerToken（Android only）
  final String? offerToken;

  /// 基础方案 ID（Android only）
  final String? basePlanId;

  /// Google Play 促销 offer id（Android only）
  final String? offerId;

  /// 获取 displayPrice（优先返回促销价，否则返回原价）
  String get displayPrice {
    if (hasPromo && promoPrice != null) {
      return promoPrice!;
    }
    return productDetails.price;
  }

  /// 获取原价（用于划线价展示）
  String? get displayOriginalPrice {
    if (hasPromo && regularPrice != null) {
      return regularPrice;
    }
    return null;
  }

  @override
  String toString() {
    return 'IapProductInfo(id: ${productDetails.id}, hasPromo: $hasPromo, '
        'displayPrice: $displayPrice, originalPrice: $displayOriginalPrice)';
  }
}
