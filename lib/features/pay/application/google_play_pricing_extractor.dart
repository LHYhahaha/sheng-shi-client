import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Extracts Google Play pricing and intro/promo offer data from ProductDetails.
///
/// Google Play subscriptions can return multiple [GooglePlayProductDetails]
/// with the same product id. Each entry points to a different base plan or
/// offer through [GooglePlayProductDetails.subscriptionIndex].
class GooglePlayPricingExtractor {
  GooglePlayPricingExtractor._();

  static List<SubscriptionOfferDetailsWrapper>? getOfferDetails(
    ProductDetails product,
  ) {
    if (!Platform.isAndroid || product is! GooglePlayProductDetails) {
      return null;
    }
    return product.productDetails.subscriptionOfferDetails;
  }

  static SubscriptionOfferDetailsWrapper? getSelectedOffer(
    ProductDetails product,
  ) {
    if (!Platform.isAndroid || product is! GooglePlayProductDetails) {
      return null;
    }
    final offers = product.productDetails.subscriptionOfferDetails;
    final index = product.subscriptionIndex;
    if (offers == null ||
        index == null ||
        index < 0 ||
        index >= offers.length) {
      return null;
    }
    return offers[index];
  }

  // 判断当前对象是不是促销 Offer
  /// 判断当前 ProductDetails 指向的方案是否为可购买促销。
  static bool isSelectedPromotionalOffer(ProductDetails product) {
    final offer = getSelectedOffer(product);
    if (offer == null) {
      return false;
    }

    final offerId = offer.offerId?.trim();
    final offerToken = offer.offerIdToken.trim();

    return offerId != null &&
        offerId.isNotEmpty &&
        offerToken.isNotEmpty &&
        offer.pricingPhases.isNotEmpty;
  }

  static SubscriptionOfferDetailsWrapper? getPromotionalOffer(
      ProductDetails product,
      ) {
    final offers = getOfferDetails(product);
    if (offers == null || offers.isEmpty) {
      return null;
    }

    // 优先使用当前 ProductDetails 指向的 Offer。
    final selected = getSelectedOffer(product);
    final selectedOfferId = selected?.offerId?.trim();

    if (selectedOfferId != null && selectedOfferId.isNotEmpty) {
      return selected;
    }

    // 当前对象不是促销时，按 Google Play 返回顺序选择第一个促销。
    for (final offer in offers) {
      final offerId = offer.offerId?.trim();

      if (offerId != null && offerId.isNotEmpty) {
        return offer;
      }
    }

    return null;
  }

  static SubscriptionOfferDetailsWrapper? getBasePlanOffer(
    ProductDetails product, {
    String? basePlanId,
  }) {
    final offers = getOfferDetails(product);
    if (offers == null || offers.isEmpty) {
      return null;
    }

    for (final offer in offers) {
      if (basePlanId != null && offer.basePlanId != basePlanId) {
        continue;
      }
      if (!_isPromotionalOffer(offer) && offer.pricingPhases.isNotEmpty) {
        return offer;
      }
    }
    return null;
  }

  static List<PricingPhaseWrapper>? getSelectedPricingPhases(
    ProductDetails product,
  ) {
    return getSelectedOffer(product)?.pricingPhases;
  }

  static PricingPhaseWrapper? getDisplayPricePhase(ProductDetails product) {
    final phases = getSelectedPricingPhases(product);
    if (phases == null || phases.isEmpty) {
      return null;
    }
    return phases.first;
  }

  static Map<String, dynamic>? extractDisplayPricing(ProductDetails product) {
    final phase = getDisplayPricePhase(product);
    if (phase == null) {
      return null;
    }
    return <String, dynamic>{
      'price': phase.formattedPrice,
      'priceMicros': phase.priceAmountMicros,
      'period': phase.billingPeriod,
      'currencyCode': product.currencyCode,
      'currencySymbol': product.currencySymbol,
    };
  }




  /// Returns pricing for the selected Google Play offer or lower base plan.
  ///
  /// Google Play may expose discounts either as a real offer with multiple
  /// pricing phases, or as multiple base plans for the same product. In the
  /// latter case, the selected lower-priced base plan is treated as promo and
  /// the higher-priced base plan as regular.
  static Map<String, dynamic>? extractPromoPricing(
      ProductDetails product,
      ) {
    if (!Platform.isAndroid) {
      return null;
    }

    // 只读取当前 ProductDetails.subscriptionIndex 对应的方案。
    final offer = getSelectedOffer(product);

    if (offer == null) {
      return null;
    }

    final offerId = offer.offerId?.trim();
    final offerToken = offer.offerIdToken.trim();
    final phases = offer.pricingPhases;

    // 必须同时具备正式 Offer ID、购买 Token 和价格阶段。
    if (offerId == null ||
        offerId.isEmpty ||
        offerToken.isEmpty ||
        phases.isEmpty) {
      return null;
    }

    final promoPhase = phases.first;

    PricingPhaseWrapper? regularPhase;

    if (phases.length >= 2) {
      regularPhase = phases.last;
    } else {
      final basePlanOffer = getBasePlanOffer(
        product,
        basePlanId: offer.basePlanId,
      );

      final basePlanPhases = basePlanOffer?.pricingPhases;

      if (basePlanPhases != null && basePlanPhases.isNotEmpty) {
        regularPhase = basePlanPhases.last;
      }
    }

    return <String, dynamic>{
      'hasPromo': true,
      'hasFreeTrial': promoPhase.priceAmountMicros == 0,

      'promoPrice': promoPhase.formattedPrice,
      'promoPriceMicros': promoPhase.priceAmountMicros,
      'promoPeriod': promoPhase.billingPeriod,
      'promoCycles': promoPhase.billingCycleCount,

      'regularPrice': regularPhase?.formattedPrice,
      'regularPriceMicros': regularPhase?.priceAmountMicros,
      'regularPeriod': regularPhase?.billingPeriod,
      'regularCycles': regularPhase?.billingCycleCount,

      'offerToken': offerToken,
      'basePlanId': offer.basePlanId,
      'offerId': offerId,
      'offerTags': offer.offerTags,
    };
  }

  static bool _isPromotionalOffer(SubscriptionOfferDetailsWrapper offer) {
    return (offer.offerId != null && offer.offerId!.isNotEmpty) ||
        _hasMultiplePricingPhases(offer);
  }

  static bool _hasMultiplePricingPhases(SubscriptionOfferDetailsWrapper offer) {
    return offer.pricingPhases.length >= 2;
  }

  static Map<String, dynamic> getOneTimePricing(ProductDetails product) {
    return <String, dynamic>{
      'price': product.price,
      'rawPrice': product.rawPrice,
      'currencyCode': product.currencyCode,
      'currencySymbol': product.currencySymbol,
    };
  }
}
