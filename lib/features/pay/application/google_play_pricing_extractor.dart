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

  static SubscriptionOfferDetailsWrapper? getPromotionalOffer(
    ProductDetails product,
  ) {
    final offers = getOfferDetails(product);
    if (offers == null || offers.isEmpty) {
      return null;
    }

    final selected = getSelectedOffer(product);
    if (selected != null && _isPromotionalOffer(selected)) {
      return selected;
    }

    for (final offer in offers) {
      if (_isPromotionalOffer(offer)) {
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

  static PricingPhaseWrapper? getPromotionalPhase(ProductDetails product) {
    final offer = getPromotionalOffer(product);
    final phases = offer?.pricingPhases;
    if (phases == null || phases.isEmpty) {
      return null;
    }
    return phases.first;
  }

  static PricingPhaseWrapper? getRegularPhase(ProductDetails product) {
    final offer = getPromotionalOffer(product);
    final phases = offer?.pricingPhases;
    if (offer == null || phases == null || phases.isEmpty) {
      return null;
    }
    final basePlanOffer = getBasePlanOffer(
      product,
      basePlanId: offer.basePlanId,
    );
    return phases.length >= 2 ? phases.last : basePlanOffer?.pricingPhases.last;
  }

  /// Returns pricing for the selected Google Play offer or lower base plan.
  ///
  /// Google Play may expose discounts either as a real offer with multiple
  /// pricing phases, or as multiple base plans for the same product. In the
  /// latter case, the selected lower-priced base plan is treated as promo and
  /// the higher-priced base plan as regular.
  static Map<String, dynamic>? extractPromoPricing(ProductDetails product) {
    if (!Platform.isAndroid) return null;

    final offer = getPromotionalOffer(product);
    if (offer == null) {
      return _extractDiscountBasePlanPricing(product);
    }

    final phases = offer.pricingPhases;
    if (phases.isEmpty) return null;

    final basePlanOffer = getBasePlanOffer(
      product,
      basePlanId: offer.basePlanId,
    );

    final basePlanPhase = basePlanOffer?.pricingPhases.last;

    if (phases.length < 2 && basePlanPhase == null) {
      return null;
    }

    final promoPhase = phases.first;
    final regularPhase = phases.length >= 2
        ? phases.last
        : basePlanPhase!;

    return <String, dynamic>{
      'hasPromo': true,

      'hasFreeTrial': promoPhase.priceAmountMicros == 0,

      'promoPrice': promoPhase.formattedPrice,
      'promoPriceMicros': promoPhase.priceAmountMicros,
      'promoPeriod': promoPhase.billingPeriod,
      'promoCycles': promoPhase.billingCycleCount,

      'regularPrice': regularPhase.formattedPrice,
      'regularPriceMicros': regularPhase.priceAmountMicros,
      'regularPeriod': regularPhase.billingPeriod,
      'regularCycles': regularPhase.billingCycleCount,

      'offerToken': offer.offerIdToken,
      'basePlanId': offer.basePlanId,
      'offerId': offer.offerId,
      'offerTags': offer.offerTags,
    };
  }

  /// Google Play may return multiple base plans for the same subscription
  /// product without an offerId. When those base plans have the same billing
  /// period but different prices, treat the selected lower-priced base plan as
  /// the current promotional price and the higher-priced base plan as regular.
  static Map<String, dynamic>? _extractDiscountBasePlanPricing(
    ProductDetails product,
  ) {
    final selectedOffer = getSelectedOffer(product);
    final selectedPhase = selectedOffer == null
        ? null
        : _singlePricingPhase(selectedOffer);
    if (selectedOffer == null || selectedPhase == null) {
      return null;
    }

    final offers = getOfferDetails(product);
    if (offers == null || offers.length < 2) {
      return null;
    }

    PricingPhaseWrapper? regularPhase;
    for (final offer in offers) {
      final phase = _singlePricingPhase(offer);
      if (phase == null) {
        continue;
      }
      if (phase.billingPeriod != selectedPhase.billingPeriod) {
        continue;
      }
      if (phase.priceAmountMicros <= selectedPhase.priceAmountMicros) {
        continue;
      }
      if (regularPhase == null ||
          phase.priceAmountMicros > regularPhase.priceAmountMicros) {
        regularPhase = phase;
      }
    }

    if (regularPhase == null) {
      return null;
    }

    return <String, dynamic>{
      'hasPromo': true,
      'hasFreeTrial': selectedPhase.priceAmountMicros == 0,

      'promoPrice': selectedPhase.formattedPrice,
      'promoPriceMicros': selectedPhase.priceAmountMicros,
      'promoPeriod': selectedPhase.billingPeriod,
      'promoCycles': selectedPhase.billingCycleCount,

      'regularPrice': regularPhase.formattedPrice,
      'regularPriceMicros': regularPhase.priceAmountMicros,
      'regularPeriod': regularPhase.billingPeriod,
      'regularCycles': regularPhase.billingCycleCount,

      'offerToken': selectedOffer.offerIdToken,
      'basePlanId': selectedOffer.basePlanId,
      'offerId': selectedOffer.offerId,
      'offerTags': selectedOffer.offerTags,
    };
  }

  static PricingPhaseWrapper? _singlePricingPhase(
    SubscriptionOfferDetailsWrapper offer,
  ) {
    return offer.pricingPhases.length == 1 ? offer.pricingPhases.first : null;
  }

  static bool hasPromo(ProductDetails product) {
    return extractPromoPricing(product)?['hasPromo'] == true;
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
