import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/utils/period_iso_parser.dart';

class IapProductInfo {
  const IapProductInfo({
    required this.productDetails,
    this.hasPromo = false,
    this.hasFreeTrial = false,
    this.promoPrice,
    this.promoPriceMicros,
    this.promoPeriod,
    this.promoCycles,
    this.regularPrice,
    this.regularPriceMicros,
    this.regularPeriod,
    this.regularCycles,
    this.offerToken,
    this.basePlanId,
    this.offerId,
    this.offerTags = const [],
  });

  /// 必须保留这个对象。
  ///
  /// 页面展示和购买时必须使用同一个 ProductDetails。
  final ProductDetails productDetails;
  final bool hasPromo;

  /// 首期是否为免费试用
  final bool hasFreeTrial;

  /// 促销格式化价格，例如 S$1.99
  final String? promoPrice;
  final int? promoPriceMicros;

  /// 单个促销计费周期，例如 P1M
  final String? promoPeriod;

  /// 促销周期执行次数，例如3
  final int? promoCycles;

  /// 正常续费价格，例如 S$9.99
  final String? regularPrice;
  final int? regularPriceMicros;

  /// 正常续费周期，例如 P1M
  final String? regularPeriod;
  final int? regularCycles;

  /// Android购买这个优惠必须传入
  final String? offerToken;
  final String? basePlanId;
  final String? offerId;
  final List<String> offerTags;

  String get displayPrice {
    if (hasPromo && promoPrice != null) {
      return promoPrice!;
    }
    return productDetails.price;
  }

  String? get displayOriginalPrice {
    if (hasPromo && regularPrice != null) {
      return regularPrice;
    }
    return null;
  }

  bool get canUseGoogleOffer =>
      offerToken != null && offerToken!.trim().isNotEmpty;

  @override
  String toString() {
    return 'IapProductInfo(id: ' +
        productDetails.id +
        ', hasPromo: ' +
        hasPromo.toString() +
        ', promoPrice: ' +
        promoPrice.toString() +
        ', promoPeriod: ' +
        promoPeriod.toString() +
        ', promoCycles: ' +
        promoCycles.toString() +
        ', regularPrice: ' +
        regularPrice.toString() +
        ', regularPeriod: ' +
        regularPeriod.toString() +
        ', basePlanId: ' +
        basePlanId.toString() +
        ', offerId: ' +
        offerId.toString() +
        ')';
  }

  String? promoDescription({String languageCode = 'zh'}) {
    if (!hasPromo ||
        promoPrice == null ||
        regularPrice == null ||
        promoPeriod == null ||
        regularPeriod == null) {
      return null;
    }

    return IapPromoTextBuilder.build(
      promoPrice: promoPrice!,
      promoPeriod: promoPeriod!,
      promoCycles: promoCycles ?? 1,
      regularPrice: regularPrice!,
      regularPeriod: regularPeriod!,
      hasFreeTrial: hasFreeTrial,
      languageCode: languageCode,
    );
  }
}
