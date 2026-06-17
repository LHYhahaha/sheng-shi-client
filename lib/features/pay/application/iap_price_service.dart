import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../core/utils/period_iso_parser.dart';
import '../domain/iap_product_info.dart';
import 'google_play_pricing_extractor.dart';

/// IAP 价格查询服务（公共）
///
/// 负责查询 Google Play / App Store 的商品价格和促销信息。
/// Store 页面和 Membership 页面都可以使用这个服务。
class IapPriceService {
  final _iap = InAppPurchase.instance;
  final _productDetailsCache = <String, ProductDetails>{};

  /// 查询商品信息
  ///
  /// [productIds] - 商品ID列表（channelProductId）
  /// 返回商品ID到商品详情的映射
  Future<Map<String, ProductDetails>> queryProducts({
    required Set<String> productIds,
  }) async {
    try {
      debugPrint('[IapPrice] 开始查询商品: $productIds');
      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('[IapPrice] 查询商品失败: ${response.error}');
        return {};
      }

      final result = <String, ProductDetails>{};
      for (final product in response.productDetails) {
        final selected = _preferProductDetails(result[product.id], product);
        _productDetailsCache[product.id] = selected;
        result[product.id] = selected;
        _logProductPricing(product);
      }

      debugPrint('[IapPrice] 查询成功: ${result.length} 个商品');
      return result;
    } catch (e, st) {
      debugPrint('[IapPrice] 查询商品异常: $e\n$st');
      return {};
    }
  }

  /// 查询单个商品信息
  Future<ProductDetails?> queryProduct({required String productId}) async {
    final results = await queryProducts(productIds: {productId});
    return results[productId];
  }

  /// 查询商品信息（包含促销信息）
  ///
  /// 与 [queryProducts] 不同，此方法返回 [IapProductInfo]，包含促销价、原价、offerToken 等。
  /// 这样调用方可以直接使用促销信息，无需重复调用提取逻辑。
  Future<Map<String, IapProductInfo>> queryProductsWithPromo({
    required Set<String> productIds,
  }) async {
    final products = await queryProducts(productIds: productIds);
    final result = <String, IapProductInfo>{};

    for (final entry in products.entries) {
      result[entry.key] = _toIapProductInfo(entry.value);
    }

    return result;
  }

  /// 将 ProductDetails 转换为 IapProductInfo
  IapProductInfo _toIapProductInfo(ProductDetails product) {
    Map<String, dynamic>? promoInfo;
    if (Platform.isAndroid) {
      promoInfo = GooglePlayPricingExtractor.extractPromoPricing(product);
    }

    if (promoInfo != null && promoInfo['hasPromo'] == true) {
      return IapProductInfo(
        productDetails: product,
        hasPromo: true,
        promoPrice: promoInfo['promoPrice'] as String?,
        promoPriceMicros: promoInfo['promoPriceMicros'] as int?,
        promoPeriod: promoInfo['promoPeriod'] as String?,
        regularPrice: promoInfo['regularPrice'] as String?,
        regularPriceMicros: promoInfo['regularPriceMicros'] as int?,
        regularPeriod: promoInfo['regularPeriod'] as String?,
        offerToken: promoInfo['offerToken'] as String?,
        basePlanId: promoInfo['basePlanId'] as String?,
        offerId: promoInfo['offerId'] as String?,
      );
    }

    return IapProductInfo(productDetails: product, hasPromo: false);
  }

  ProductDetails _preferProductDetails(
    ProductDetails? existing,
    ProductDetails candidate,
  ) {
    if (existing == null || !Platform.isAndroid) {
      return candidate;
    }

    final existingHasPromo = GooglePlayPricingExtractor.hasPromo(existing);
    final candidateHasPromo = GooglePlayPricingExtractor.hasPromo(candidate);
    if (candidateHasPromo && !existingHasPromo) {
      return candidate;
    }
    return existing;
  }

  /// 提取商品的促销信息（仅 Android/Google Play）
  ///
  /// 返回包含促销价、续费价、周期的 Map，如果不是促销商品则返回 null
  Map<String, dynamic>? extractPromoInfo(ProductDetails product) {
    if (!Platform.isAndroid) return null;
    return GooglePlayPricingExtractor.extractPromoPricing(product);
  }

  /// 获取商品的 IAP 价格文案
  String getPriceLabel(ProductDetails product) => product.price;

  /// 获取商品的原始价格文案（如果有促销）
  String? getOriginalPriceLabel(ProductDetails product) {
    if (!Platform.isAndroid) return null;
    final promo = extractPromoInfo(product);
    if (promo != null) {
      return promo['regularPrice'] as String?;
    }
    return null;
  }

  /// 获取商品的促销价格文案（如果有促销）
  String? getPromotionPriceLabel(ProductDetails product) {
    if (!Platform.isAndroid) return null;
    final promo = extractPromoInfo(product);
    if (promo != null) {
      return promo['promoPrice'] as String?;
    }
    return null;
  }

  /// 获取商品的促销描述文案（中英文）
  ///
  /// 示例：
  /// - 中文： "前2周 $0.99/周，之后 $9.99/周"
  /// - 英文： "$0.99/week for first 2 weeks, then $9.99/week"
  String? getPromoDescription(ProductDetails product, {String? languageCode}) {
    if (!Platform.isAndroid) return null;
    final promo = extractPromoInfo(product);
    if (promo == null || promo['hasPromo'] != true) return null;

    return PeriodIsoParser.buildPromoDescription(
      promoPrice: promo['promoPrice'] as String?,
      regularPrice: promo['regularPrice'] as String?,
      promoPeriodIso: promo['promoPeriod'] as String?,
      regularPeriodIso: promo['regularPeriod'] as String?,
      languageCode: languageCode,
    );
  }

  /// 打印商品价格详情（调试用）
  void _logProductPricing(ProductDetails product) {
    debugPrint('[IapPrice] 商品: ${product.id}');
    debugPrint('  IAP 价格: ${product.price} (raw: ${product.rawPrice})');
    debugPrint('  货币: ${product.currencyCode} ${product.currencySymbol}');

    if (!Platform.isAndroid) return;

    if (product is GooglePlayProductDetails) {
      final offers =
          GooglePlayPricingExtractor.getOfferDetails(product) ??
          const <dynamic>[];
      debugPrint(
        '  [GooglePlay] subscriptionIndex: ${product.subscriptionIndex}',
      );
      debugPrint('  [GooglePlay] offers count: ${offers.length}');
      for (var i = 0; i < offers.length; i += 1) {
        final offer = offers[i];
        debugPrint(
          '  [GooglePlay] offer[$i] basePlan=${offer.basePlanId}, offerId=${offer.offerId}, phases=${offer.pricingPhases.length}',
        );
        for (var j = 0; j < offer.pricingPhases.length; j += 1) {
          final phase = offer.pricingPhases[j];
          debugPrint(
            '    phase[$j] price=${phase.formattedPrice}, micros=${phase.priceAmountMicros}, period=${phase.billingPeriod}, cycles=${phase.billingCycleCount}',
          );
        }
      }
    }

    final promo = extractPromoInfo(product);
    if (promo != null && promo['hasPromo'] == true) {
      debugPrint('  [促销] 首期价: ${promo['promoPrice']}');
      debugPrint('  [促销] 续费价: ${promo['regularPrice']}');
      debugPrint('  [促销] 首期周期: ${promo['promoPeriod']}');
      debugPrint('  [促销] 续费周期: ${promo['regularPeriod']}');
    } else {
      debugPrint('  [促销] 无促销');
    }
  }

  /// 清理资源
  void dispose() {
    _productDetailsCache.clear();
  }
}
