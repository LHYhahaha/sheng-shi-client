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
      final loggedProductIds = <String>{};

      for (final product in response.productDetails) {
        final selected = _preferProductDetails(result[product.id], product);

        // 循环中只更新临时结果。
        // 同一个 productId 返回多个 ProductDetails 时，
        // _preferProductDetails 会保留第一个促销 Offer。
        result[product.id] = selected;

        // 同一个商品的 subscriptionOfferDetails 通常相同，
        // 只完整打印一次所有方案。
        if (loggedProductIds.add(product.id)) {
          _logProductPricing(product);
        }

        if (product is GooglePlayProductDetails) {
          final currentOffer = GooglePlayPricingExtractor.getSelectedOffer(
            product,
          );

          debugPrint(
            '[IapPrice] Google返回对象: '
            'productId=${product.id}, '
            'subscriptionIndex=${product.subscriptionIndex}, '
            'basePlanId=${currentOffer?.basePlanId}, '
            'offerId=${currentOffer?.offerId}',
          );
        }
      }

      // 所有 ProductDetails 都比较结束后，
      // 再把最终选中的对象写入缓存。
      _productDetailsCache.addAll(result);

      for (final entry in result.entries) {
        final product = entry.value;

        final selectedOffer = GooglePlayPricingExtractor.getSelectedOffer(
          product,
        );

        final selectedIndex = product is GooglePlayProductDetails
            ? product.subscriptionIndex
            : null;

        final firstPhase = selectedOffer?.pricingPhases.isNotEmpty == true
            ? selectedOffer!.pricingPhases.first
            : null;

        debugPrint(
          '[IapPrice] 最终选中: '
          'productId=${entry.key}, '
          'subscriptionIndex=$selectedIndex, '
          'basePlanId=${selectedOffer?.basePlanId}, '
          'offerId=${selectedOffer?.offerId}, '
          'price=${firstPhase?.formattedPrice ?? product.price}, '
          'offerToken=${selectedOffer?.offerIdToken}',
        );
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
    if (!Platform.isAndroid) {
      return IapProductInfo(productDetails: product, hasPromo: false);
    }

    final promoInfo = GooglePlayPricingExtractor.extractPromoPricing(product);

    if (promoInfo == null || promoInfo['hasPromo'] != true) {
      return IapProductInfo(productDetails: product, hasPromo: false);
    }

    return IapProductInfo(
      // 必须保存最终选中的这个 ProductDetails。
      productDetails: product,

      hasPromo: true,
      hasFreeTrial: promoInfo['hasFreeTrial'] as bool? ?? false,

      promoPrice: promoInfo['promoPrice'] as String?,
      promoPriceMicros: promoInfo['promoPriceMicros'] as int?,
      promoPeriod: promoInfo['promoPeriod'] as String?,
      promoCycles: promoInfo['promoCycles'] as int?,

      regularPrice: promoInfo['regularPrice'] as String?,
      regularPriceMicros: promoInfo['regularPriceMicros'] as int?,
      regularPeriod: promoInfo['regularPeriod'] as String?,
      regularCycles: promoInfo['regularCycles'] as int?,

      // 购买时使用的 Offer Token。
      offerToken: promoInfo['offerToken'] as String?,

      basePlanId: promoInfo['basePlanId'] as String?,

      offerId: promoInfo['offerId'] as String?,

      offerTags:
          (promoInfo['offerTags'] as List?)?.cast<String>() ?? const <String>[],
    );
  }

  ProductDetails _preferProductDetails(
    ProductDetails? existing,
    ProductDetails candidate,
  ) {
    if (existing == null || !Platform.isAndroid) {
      return candidate;
    }

    final existingIsOffer =
        GooglePlayPricingExtractor.isSelectedPromotionalOffer(existing);

    final candidateIsOffer =
        GooglePlayPricingExtractor.isSelectedPromotionalOffer(candidate);

    final existingIndex = existing is GooglePlayProductDetails
        ? existing.subscriptionIndex
        : null;

    final candidateIndex = candidate is GooglePlayProductDetails
        ? candidate.subscriptionIndex
        : null;

    final existingOffer = GooglePlayPricingExtractor.getSelectedOffer(existing);

    final candidateOffer = GooglePlayPricingExtractor.getSelectedOffer(
      candidate,
    );

    debugPrint(
      '[IapPrice] 比较商品方案: '
      'productId=${candidate.id}, '
      'existingIndex=$existingIndex, '
      'existingOfferId=${existingOffer?.offerId}, '
      'candidateIndex=$candidateIndex, '
      'candidateOfferId=${candidateOffer?.offerId}',
    );

    // 已经选中了一个促销 Offer：
    // 后续即使又返回其他 Offer，也继续保留第一个。
    if (existingIsOffer) {
      debugPrint(
        '[IapPrice] 已有促销方案，保留第一个: '
        'productId=${existing.id}, '
        'subscriptionIndex=$existingIndex, '
        'offerId=${existingOffer?.offerId}',
      );

      return existing;
    }

    // 当前还没有促销，而 candidate 是促销：
    // 选择第一个出现的促销 Offer。
    if (candidateIsOffer) {
      debugPrint(
        '[IapPrice] 选择第一个促销方案: '
        'productId=${candidate.id}, '
        'subscriptionIndex=$candidateIndex, '
        'offerId=${candidateOffer?.offerId}',
      );

      return candidate;
    }

    // 两个都是基础方案时，保留第一个。
    debugPrint(
      '[IapPrice] 当前没有促销方案，保留第一个基础方案: '
      'productId=${existing.id}, '
      'subscriptionIndex=$existingIndex',
    );

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
  /// - 中文： "前2周 $14.99/周，之后 $19.99/周。"
  /// - 英文： "$14.99/week for first 2 weeks, then $19.99/week"
  String? getPromoDescription(ProductDetails product, {String? languageCode}) {
    if (!Platform.isAndroid) return null;
    final promo = extractPromoInfo(product);
    if (promo == null || promo['hasPromo'] != true) return null;

    final promoPrice = promo['promoPrice'] as String?;
    final regularPrice = promo['regularPrice'] as String?;
    final promoPeriod = promo['promoPeriod'] as String?;
    final regularPeriod = promo['regularPeriod'] as String?;
    if (promoPrice == null ||
        regularPrice == null ||
        promoPeriod == null ||
        regularPeriod == null) {
      return null;
    }

    return IapPromoTextBuilder.build(
      promoPrice: promoPrice,
      promoPeriod: promoPeriod,
      promoCycles: promo['promoCycles'] as int? ?? 1,
      regularPrice: regularPrice,
      regularPeriod: regularPeriod,
      hasFreeTrial: promo['hasFreeTrial'] as bool? ?? false,
      languageCode: languageCode ?? 'zh',
    );
  }

  /// 打印商品价格详情（调试用）
  void _logProductPricing(ProductDetails product) {
    debugPrint('');
    debugPrint('================ IAP 商品详情开始 ================');
    debugPrint('[IapPrice] 商品ID: ${product.id}');
    debugPrint('[IapPrice] 标题: ${product.title}');
    debugPrint('[IapPrice] 描述: ${product.description}');
    debugPrint(
      '[IapPrice] 默认价格: ${product.price} '
      '(raw: ${product.rawPrice})',
    );
    debugPrint(
      '[IapPrice] 货币: '
      'code=${product.currencyCode}, '
      'symbol=${product.currencySymbol}',
    );

    if (!Platform.isAndroid) {
      debugPrint('[IapPrice] 当前不是 Android，不打印 Google Play Offer');
      debugPrint('================ IAP 商品详情结束 ================');
      debugPrint('');
      return;
    }

    if (product is! GooglePlayProductDetails) {
      debugPrint('[IapPrice] 当前 ProductDetails 不是 GooglePlayProductDetails');
      debugPrint('================ IAP 商品详情结束 ================');
      debugPrint('');
      return;
    }

    final offers =
        product.productDetails.subscriptionOfferDetails ?? const <dynamic>[];

    final selectedIndex = product.subscriptionIndex;

    debugPrint('[GooglePlay] subscriptionIndex: $selectedIndex');
    debugPrint('[GooglePlay] 全部方案数量: ${offers.length}');

    if (offers.isEmpty) {
      debugPrint('[GooglePlay] 当前商品没有返回基础方案或促销方案');
      debugPrint('================ IAP 商品详情结束 ================');
      debugPrint('');
      return;
    }

    for (var offerIndex = 0; offerIndex < offers.length; offerIndex++) {
      final offer = offers[offerIndex];
      final isSelected = offerIndex == selectedIndex;

      final offerId = offer.offerId;
      final offerTags = offer.offerTags;
      final phases = offer.pricingPhases;

      final hasOfferId =
          offerId != null && offerId.toString().trim().isNotEmpty;

      final hasMultiplePhases = phases.length > 1;

      final hasFreeTrial =
          phases.isNotEmpty && phases.first.priceAmountMicros == 0;

      final isPromotion = hasOfferId || hasMultiplePhases || hasFreeTrial;

      debugPrint('');
      debugPrint(
        '---------------- 方案[$offerIndex] '
        '${isSelected ? "【当前 ProductDetails 选中】" : ""} ----------------',
      );

      debugPrint('[GooglePlay] basePlanId: ${offer.basePlanId}');
      debugPrint('[GooglePlay] offerId: ${offer.offerId}');
      debugPrint('[GooglePlay] offerTags: ${offer.offerTags}');
      debugPrint('[GooglePlay] offerToken: ${offer.offerIdToken}');
      debugPrint('[GooglePlay] 当前方案是否被选中: $isSelected');

      debugPrint(
        '[GooglePlay] 资格Offer判断: '
        'offerIdNotEmpty=$hasOfferId, '
        'phaseCount=${phases.length}, '
        'firstPriceMicros=${phases.isEmpty ? null : phases.first.priceAmountMicros}',
      );
      debugPrint('[GooglePlay] pricingPhases数量: ${phases.length}');
      debugPrint('[GooglePlay] 是否正式Offer: $hasOfferId');
      debugPrint('[GooglePlay] 是否多阶段价格: $hasMultiplePhases');
      debugPrint('[GooglePlay] 是否免费试用: $hasFreeTrial');
      debugPrint('[GooglePlay] 是否判定为促销: $isPromotion');

      if (phases.isEmpty) {
        debugPrint('[GooglePlay] 此方案没有价格阶段');
        continue;
      }

      for (var phaseIndex = 0; phaseIndex < phases.length; phaseIndex++) {
        final phase = phases[phaseIndex];

        final cycleDescription = phase.billingCycleCount == 0
            ? '持续续费/无限次'
            : '执行 ${phase.billingCycleCount} 次';

        debugPrint('  [价格阶段][$phaseIndex]');
        debugPrint('    formattedPrice: ${phase.formattedPrice}');
        debugPrint('    priceAmountMicros: ${phase.priceAmountMicros}');
        debugPrint('    billingPeriod: ${phase.billingPeriod}');
        debugPrint(
          '    billingCycleCount: ${phase.billingCycleCount} '
          '($cycleDescription)',
        );
        debugPrint('    recurrenceMode: ${phase.recurrenceMode}');
        debugPrint('    是否免费: ${phase.priceAmountMicros == 0}');
      }

      if (isPromotion && phases.isNotEmpty) {
        final firstPhase = phases.first;
        final lastPhase = phases.last;

        debugPrint('[促销汇总] 首期价格: ${firstPhase.formattedPrice}');
        debugPrint('[促销汇总] 首期周期: ${firstPhase.billingPeriod}');
        debugPrint('[促销汇总] 首期执行次数: ${firstPhase.billingCycleCount}');

        if (phases.length >= 2) {
          debugPrint('[促销汇总] 后续价格: ${lastPhase.formattedPrice}');
          debugPrint('[促销汇总] 后续周期: ${lastPhase.billingPeriod}');
          debugPrint('[促销汇总] 后续执行次数: ${lastPhase.billingCycleCount}');
        }
      }
    }

    debugPrint('');
    debugPrint('================ IAP 商品详情结束 ================');
    debugPrint('');
  }

  /// 清理资源
  void dispose() {
    _productDetailsCache.clear();
  }
}
