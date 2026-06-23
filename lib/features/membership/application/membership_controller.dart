import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/auth/session_cleanup_types.dart';
import '../../../core/utils/period_iso_parser.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/application/google_play_pricing_extractor.dart';
import '../../pay/application/iap_pending_purchase_cleaner.dart';
import '../../pay/application/iap_price_service.dart';
import '../../pay/application/payment_loading_controller.dart';
import '../../pay/provider/iap_price_service_provider.dart';
import '../../pay/provider/iap_purchase_service_provider.dart';
import '../../pay/provider/pay_repository_provider.dart';
import '../data/membership_repository_provider.dart';
import '../domain/membership_plan.dart';

final membershipControllerProvider =
    NotifierProvider<MembershipController, MembershipState>(
      MembershipController.new,
    );

enum MembershipPurchaseStatus {
  idle,
  creatingOrder,
  waitingPayment,
  verifying,
  pending,
  success,
  failed,
  cancelled,
}

enum MembershipPurchaseFailureKind { orderCreation, payment, verification }

class MembershipState {
  const MembershipState({
    required this.isLoading,
    required this.isActive,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.plans,
    required this.selectedPlanId,
    required this.confirmationPlanId,
    required this.purchaseStatus,
    required this.purchaseFailureKind,
    required this.iapProductDetails,
    this.error,
  });

  const MembershipState.initial()
    : isLoading = true,
      isActive = false,
      heroTitle = '',
      heroSubtitle = '',
      plans = const [],
      selectedPlanId = null,
      confirmationPlanId = null,
      purchaseStatus = MembershipPurchaseStatus.idle,
      purchaseFailureKind = null,
      iapProductDetails = const {},
      error = null;

  final bool isLoading;
  final bool isActive;
  final String heroTitle;
  final String heroSubtitle;
  final List<MembershipPlan> plans;
  final String? selectedPlanId;
  final String? confirmationPlanId;
  final MembershipPurchaseStatus purchaseStatus;
  final MembershipPurchaseFailureKind? purchaseFailureKind;
  final Map<String, ProductDetails> iapProductDetails;
  final Object? error;

  bool get hasContent => !isLoading && error == null;

  MembershipPlan? get selectedPlan => planById(selectedPlanId);

  MembershipPlan? get confirmationPlan => planById(confirmationPlanId);

  MembershipPlan? planById(String? id) {
    if (id == null) {
      return null;
    }

    for (final plan in plans) {
      if (plan.id == id) {
        return plan;
      }
    }
    return null;
  }

  MembershipState copyWith({
    bool? isLoading,
    bool? isActive,
    String? heroTitle,
    String? heroSubtitle,
    List<MembershipPlan>? plans,
    String? selectedPlanId,
    String? confirmationPlanId,
    MembershipPurchaseStatus? purchaseStatus,
    MembershipPurchaseFailureKind? purchaseFailureKind,
    Map<String, ProductDetails>? iapProductDetails,
    Object? error,
    bool clearError = false,
    bool clearConfirmation = false,
    bool clearPurchaseFailure = false,
  }) {
    return MembershipState(
      isLoading: isLoading ?? this.isLoading,
      isActive: isActive ?? this.isActive,
      heroTitle: heroTitle ?? this.heroTitle,
      heroSubtitle: heroSubtitle ?? this.heroSubtitle,
      plans: plans ?? this.plans,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      confirmationPlanId: clearConfirmation
          ? null
          : confirmationPlanId ?? this.confirmationPlanId,
      purchaseStatus: purchaseStatus ?? this.purchaseStatus,
      purchaseFailureKind: clearPurchaseFailure
          ? null
          : purchaseFailureKind ?? this.purchaseFailureKind,
      iapProductDetails: iapProductDetails ?? this.iapProductDetails,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MembershipController extends Notifier<MembershipState> {
  static const _packageName = 'com.yushi.drama.client';
  static const _membershipProductType = 2;
  static const _purchaseResultTimeout = Duration(seconds: 30);
  static const _paymentSheetDismissDelay = Duration(milliseconds: 260);

  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  MembershipState build() => const MembershipState.initial();

  void resetForSessionCleanup(SessionCleanupReason reason) {
    ++_generation;
    ++_purchaseGeneration;
    state = const MembershipState.initial();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearConfirmation: true,
    );

    try {
      final data = await ref
          .read(membershipRepositoryProvider)
          .fetchMembership();

      if (!_isCurrent(generation)) {
        return;
      }

      final iapDetails = await _queryIapProducts(data.plans);
      if (!_isCurrent(generation)) {
        return;
      }

      final plans = _mergeIapPricing(data.plans, iapDetails);

      state = state.copyWith(
        isLoading: false,
        isActive: data.isActive,
        heroTitle: data.heroTitle,
        heroSubtitle: data.heroSubtitle,
        plans: List<MembershipPlan>.unmodifiable(plans),
        selectedPlanId: plans.isEmpty ? null : plans.first.id,
        iapProductDetails: iapDetails,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[Membership] load failed: $error\n$stackTrace');
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> retry() => load();

  void selectPlan(String id) {
    if (state.planById(id) == null) {
      return;
    }
    state = state.copyWith(selectedPlanId: id);
  }

  void selectPlanAndConfirm(String id) {
    selectPlan(id);
    showConfirmation();
  }

  void showConfirmation() {
    final selectedPlan = state.selectedPlan;
    if (selectedPlan == null) {
      return;
    }

    _purchaseGeneration++;
    state = state.copyWith(
      confirmationPlanId: selectedPlan.id,
      purchaseStatus: MembershipPurchaseStatus.idle,
      clearError: true,
      clearPurchaseFailure: true,
    );
  }

  void hideConfirmation() {
    _purchaseGeneration++;
    state = state.copyWith(
      purchaseStatus: MembershipPurchaseStatus.idle,
      clearConfirmation: true,
      clearPurchaseFailure: true,
    );
  }

  Future<void> confirmPurchase() async {
    if (state.confirmationPlan == null ||
        state.purchaseStatus != MembershipPurchaseStatus.idle) {
      return;
    }

    final purchaseGeneration = _purchaseGeneration;
    final plan = state.confirmationPlan!;
    StreamSubscription<PurchaseDetails>? sub;
    StreamSubscription<Object>? errorSub;
    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    loading.show();
    try {
      final platformProductId = plan.platformProductId;
      if (platformProductId == null || platformProductId.isEmpty) {
        throw Exception('Plan has no platform product id: ${plan.id}');
      }

      var productDetails = state.iapProductDetails[platformProductId];
      if (productDetails == null) {
        final queried = await ref
            .read(iapPriceServiceProvider)
            .queryProduct(productId: platformProductId);
        productDetails = queried;
      }
      if (productDetails == null) {
        throw Exception('Product details not found for $platformProductId');
      }

      state = state.copyWith(
        purchaseStatus: MembershipPurchaseStatus.creatingOrder,
        clearError: true,
        clearPurchaseFailure: true,
      );

      final payRepository = ref.read(payRepositoryProvider);
      await ref
          .read(iapPendingPurchaseCleanerProvider)
          .cleanupBeforeCreateOrder(
            source: 'membership',
            productIds: const <String>{},
          );
      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }

      final paymentOrder = await payRepository.createPaymentOrder(
        productId: int.tryParse(plan.id) ?? 0,
        productType: _membershipProductType,
        scene: 'membership',
      );

      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }

      final iapService = ref.read(iapPurchaseServiceProvider);
      if (iapService == null) {
        throw Exception('IAP purchase service not available');
      }

      final purchaseCompleter = Completer<PurchaseDetails?>();
      sub = iapService.purchaseStream.listen((details) {
        final isCurrentProduct = details.productID == productDetails!.id;
        final isPurchaseError = details.status == PurchaseStatus.error;
        final isCancellation =
            details.status.name == 'canceled' ||
            details.status == PurchaseStatus.error &&
                _isUserCancelledPurchase(details);
        if ((isCurrentProduct || isCancellation || isPurchaseError) &&
            !purchaseCompleter.isCompleted) {
          purchaseCompleter.complete(details);
        }
      });
      errorSub = iapService.purchaseErrorStream.listen((error) {
        if (!purchaseCompleter.isCompleted) {
          purchaseCompleter.completeError(error);
        }
      });

      state = state.copyWith(
        purchaseStatus: MembershipPurchaseStatus.waitingPayment,
      );
      await Future<void>.delayed(_paymentSheetDismissDelay);
      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }

      final started = await iapService.buyProduct(
        product: productDetails,
        applicationUserName: iapService.buildOrderApplicationUserName(
          orderNo: paymentOrder.orderNo,
          clientOrderNo: paymentOrder.clientOrderNo,
        ),
      );
      if (!started) {
        throw Exception('Failed to launch IAP purchase');
      }

      final purchaseDetails = await purchaseCompleter.future.timeout(
        _purchaseResultTimeout,
        onTimeout: () {
          debugPrint('[Membership] purchase result timed out.');
          return null;
        },
      );

      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }
      if (purchaseDetails == null) {
        _markPurchaseCancelled(plan.id);
        return;
      }

      if (purchaseDetails.status == PurchaseStatus.pending) {
        state = state.copyWith(
          purchaseStatus: MembershipPurchaseStatus.pending,
        );
        return;
      }
      if (purchaseDetails.status == PurchaseStatus.error) {
        if (_isUserCancelledPurchase(purchaseDetails)) {
          _markPurchaseCancelled(plan.id);
          return;
        }
        throw Exception('Purchase failed: ${purchaseDetails.error}');
      }
      if (purchaseDetails.status.name == 'canceled') {
        _markPurchaseCancelled(plan.id);
        return;
      }
      if (purchaseDetails.status != PurchaseStatus.purchased &&
          purchaseDetails.status != PurchaseStatus.restored) {
        throw Exception(
          'Unsupported purchase status: ${purchaseDetails.status}',
        );
      }

      state = state.copyWith(
        purchaseStatus: MembershipPurchaseStatus.verifying,
      );
      final verifyResult = await payRepository.verifyGooglePayment(
        orderNo: paymentOrder.orderNo,
        channelProductId: purchaseDetails.productID,
        packageName: _packageName,
        productType: _membershipProductType,
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
        channelOrderId: purchaseDetails.purchaseID,
        rawReceipt: purchaseDetails.verificationData.source,
      );

      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }
      if (verifyResult.orderStatus != 'ORDER_STATUS_SUCCESS') {
        throw Exception(
          'Payment verification returned ${verifyResult.orderStatus}',
        );
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await iapService.completePurchase(purchaseDetails);
      }

      await _refreshAfterPurchase();

      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }
      state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.success);
    } catch (error, stackTrace) {
      debugPrint('[Membership] purchase failed: $error\n$stackTrace');
      if (purchaseGeneration == _purchaseGeneration) {
        final failureKind = switch (state.purchaseStatus) {
          MembershipPurchaseStatus.creatingOrder =>
            MembershipPurchaseFailureKind.orderCreation,
          MembershipPurchaseStatus.verifying =>
            MembershipPurchaseFailureKind.verification,
          _ => MembershipPurchaseFailureKind.payment,
        };
        state = state.copyWith(
          purchaseStatus: MembershipPurchaseStatus.failed,
          purchaseFailureKind: failureKind,
          clearError: true,
        );
      }
    } finally {
      await sub?.cancel();
      await errorSub?.cancel();
      loading.hide();
    }
  }

  void cancelPurchase() {
    if (state.purchaseStatus != MembershipPurchaseStatus.idle) {
      return;
    }
    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.cancelled);
  }

  void _markPurchaseCancelled(String planId) {
    if (state.confirmationPlanId != planId) {
      return;
    }
    state = state.copyWith(
      purchaseStatus: MembershipPurchaseStatus.cancelled,
      clearConfirmation: true,
      clearError: true,
      clearPurchaseFailure: true,
    );
  }

  bool _isUserCancelledPurchase(PurchaseDetails details) {
    final code = details.error?.code.toLowerCase();
    final message = details.error?.message.toLowerCase();
    return code?.contains('cancel') == true ||
        code?.contains('user') == true ||
        message?.contains('cancel') == true ||
        message?.contains('user') == true;
  }

  Future<Map<String, ProductDetails>> _queryIapProducts(
    List<MembershipPlan> plans,
  ) async {
    final productIds = <String>{};
    for (final plan in plans) {
      final productId = plan.platformProductId;
      if (productId != null && productId.isNotEmpty) {
        productIds.add(productId);
      }
    }
    if (productIds.isEmpty) {
      return const {};
    }
    return ref
        .read(iapPriceServiceProvider)
        .queryProducts(productIds: productIds);
  }

  List<MembershipPlan> _mergeIapPricing(
    List<MembershipPlan> plans,
    Map<String, ProductDetails> iapDetails,
  ) {
    if (iapDetails.isEmpty) {
      return plans;
    }

    final priceService = ref.read(iapPriceServiceProvider);
    return [
      for (final plan in plans)
        _mergePlanPricing(
          plan,
          iapDetails[plan.platformProductId],
          priceService,
        ),
    ];
  }

  MembershipPlan _mergePlanPricing(
    MembershipPlan plan,
    ProductDetails? product,
    IapPriceService priceService,
  ) {
    if (product == null) {
      return plan;
    }

    final promo = priceService.extractPromoInfo(product);
    if (promo != null && promo['hasPromo'] == true) {
      final promoPrice = promo['promoPrice'] as String? ?? product.price;
      final regularPrice = promo['regularPrice'] as String?;
      final promoPeriod = promo['promoPeriod'] as String?;
      final regularPeriod = promo['regularPeriod'] as String?;
      final promoMicros = promo['promoPriceMicros'] as int?;
      final regularMicros = promo['regularPriceMicros'] as int?;

      return _copyPlan(
        plan,
        title: _cleanTitle(product.title),
        priceLabel: promoPrice,
        originalPriceLabel: regularPrice ?? plan.originalPriceLabel,
        promotionPriceLabel: promoPrice,
        hasPromo: true,
        regularPriceLabel: regularPrice,
        promoPeriodIso: promoPeriod,
        regularPeriodIso: regularPeriod,
        dailyPriceLabel: _dailyPriceLabel(
          priceMicros: promoMicros ?? regularMicros,
          periodIso: promoPeriod ?? regularPeriod ?? plan.regularPeriodIso,
          currencyCode: product.currencyCode,
          currencySymbol: product.currencySymbol,
        ),
      );
    }

    final displayPricing = GooglePlayPricingExtractor.extractDisplayPricing(
      product,
    );
    return _copyPlan(
      plan,
      title: _cleanTitle(product.title),
      priceLabel: product.price,
      hasPromo: false,
      dailyPriceLabel: _dailyPriceLabel(
        priceMicros:
            displayPricing?['priceMicros'] as int? ??
            (product.rawPrice * 1000000).round(),
        periodIso:
            displayPricing?['period'] as String? ?? plan.regularPeriodIso,
        currencyCode: product.currencyCode,
        currencySymbol:
            displayPricing?['currencySymbol'] as String? ??
            product.currencySymbol,
      ),
    );
  }

  MembershipPlan _copyPlan(
    MembershipPlan plan, {
    String? title,
    String? priceLabel,
    String? dailyPriceLabel,
    String? originalPriceLabel,
    String? promotionPriceLabel,
    bool? hasPromo,
    String? regularPriceLabel,
    String? promoPeriodIso,
    String? regularPeriodIso,
  }) {
    return MembershipPlan(
      id: plan.id,
      title: title ?? plan.title,
      priceLabel: priceLabel ?? plan.priceLabel,
      dailyPriceLabel: dailyPriceLabel ?? plan.dailyPriceLabel,
      period: plan.period,
      platformProductId: plan.platformProductId,
      badgeLabel: plan.badgeLabel,
      originalPriceLabel: originalPriceLabel ?? plan.originalPriceLabel,
      promotionPriceLabel: promotionPriceLabel ?? plan.promotionPriceLabel,
      hasPromo: hasPromo ?? plan.hasPromo,
      regularPriceLabel: regularPriceLabel ?? plan.regularPriceLabel,
      promoCountdownEndMs: plan.promoCountdownEndMs,
      description: plan.description,
      enabled: plan.enabled,
      promoPeriodIso: promoPeriodIso ?? plan.promoPeriodIso,
      regularPeriodIso: regularPeriodIso ?? plan.regularPeriodIso,
    );
  }

  String _cleanTitle(String title) =>
      title.split(RegExp(r'\s*\(')).first.trim();

  String _dailyPriceLabel({
    required int? priceMicros,
    required String? periodIso,
    required String currencyCode,
    required String currencySymbol,
  }) {
    if (priceMicros == null ||
        priceMicros < 0 ||
        periodIso == null ||
        periodIso.isEmpty ||
        (currencyCode.isEmpty && currencySymbol.isEmpty)) {
      return '';
    }
    final days = _periodToDays(periodIso);
    if (days <= 0) {
      return '';
    }
    final daily = priceMicros / 1000000.0 / days;
    final roundedUp = (daily * 100).ceil() / 100;
    return _formatCurrency(currencyCode, currencySymbol, roundedUp);
  }

  String _formatCurrency(
    String currencyCode,
    String currencySymbol,
    double amount,
  ) {
    final normalizedSymbol = currencySymbol.trim();
    if (normalizedSymbol.isNotEmpty) {
      return '$normalizedSymbol${amount.toStringAsFixed(2)}';
    }
    final normalizedCode = currencyCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      return amount.toStringAsFixed(2);
    }
    return '$normalizedCode ${amount.toStringAsFixed(2)}';
  }

  Future<void> _refreshAfterPurchase() async {
    await ref.read(entitlementControllerProvider.notifier).load();
  }

  int _periodToDays(String periodIso) {
    final parsed = PeriodIsoParser.parse(periodIso);
    if (parsed == null) {
      return 0;
    }
    final value = parsed['value'] as int;
    final unit = parsed['unit'] as String;
    return switch (unit) {
      'D' => value,
      'W' => value * 7,
      'M' => value * 30,
      'Y' => value * 365,
      _ => 0,
    };
  }

  bool _isCurrent(int generation) => generation == _generation;

  bool _isCurrentPurchase(int purchaseGeneration, String planId) {
    return purchaseGeneration == _purchaseGeneration &&
        state.confirmationPlanId == planId &&
        state.purchaseStatus != MembershipPurchaseStatus.idle;
  }
}
