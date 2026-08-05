import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_provider.dart';
import '../../../core/auth/session_cleanup_types.dart';
import '../../../core/auth/user_info_store.dart';
import '../../../core/notification/startup_notification_permission_reporter.dart';
import '../../../core/runtime/api_region_code_provider.dart';
import '../../../core/utils/period_iso_parser.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/application/google_play_pricing_extractor.dart';
import '../../pay/application/iap_pending_purchase_cleaner.dart';
import '../../pay/application/iap_price_service.dart';
import '../../pay/application/payment_loading_controller.dart';
import '../../pay/application/payment_purchase_coordinator.dart';
import '../../pay/domain/pay_channel.dart';
import '../../pay/domain/payment_method_options.dart';
import '../../pay/provider/iap_price_service_provider.dart';
import '../../pay/provider/iap_purchase_service_provider.dart';
import '../../pay/provider/pay_repository_provider.dart';
import '../../pay/provider/payment_purchase_coordinator_provider.dart';
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

enum MembershipPurchaseFailureKind {
  paymentOptions,
  orderCreation,
  payment,
  verification,
}

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
    required this.paymentMethods,
    required this.selectedPaymentMethodCode,
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
      paymentMethods = const [],
      selectedPaymentMethodCode = null,
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
  final List<PaymentMethodOption> paymentMethods;
  final String? selectedPaymentMethodCode;
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
    List<PaymentMethodOption>? paymentMethods,
    String? selectedPaymentMethodCode,
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
      paymentMethods: paymentMethods ?? this.paymentMethods,
      selectedPaymentMethodCode:
          selectedPaymentMethodCode ?? this.selectedPaymentMethodCode,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MembershipController extends Notifier<MembershipState> {
  static const _packageName = 'com.novashort.shortdrama';
  static const _membershipProductType = 2;
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

  Future<void> refreshSilently() async {
    if (state.isLoading) {
      return;
    }

    final generation = ++_generation;
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
      final selectedPlanId = state.selectedPlanId;
      final nextSelectedPlanId = plans.any((plan) => plan.id == selectedPlanId)
          ? selectedPlanId
          : plans.isEmpty
          ? null
          : plans.first.id;

      state = state.copyWith(
        isLoading: false,
        isActive: data.isActive,
        heroTitle: data.heroTitle,
        heroSubtitle: data.heroSubtitle,
        plans: List<MembershipPlan>.unmodifiable(plans),
        selectedPlanId: nextSelectedPlanId,
        iapProductDetails: iapDetails,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[Membership] silent refresh failed: $error\n$stackTrace');
    }
  }

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

  /// 当前选中商品的购买入口：先取服务端支付方式，再决定是否展示收银台。
  Future<void> purchaseSelectedPlan() async {
    final plan = state.selectedPlan;
    if (plan == null) {
      return;
    }

    try {
      final options = await _fetchPaymentOptions(plan);
      final supportedMethods = _supportedPaymentMethods(options.options);
      if (supportedMethods.isEmpty) {
        await _startPayment(plan, _defaultPaymentChannel);
      } else if (supportedMethods.length == 1) {
        await _startPayment(
          plan,
          supportedMethods.single.payChannel,
          paymentMethod: supportedMethods.single,
        );
      } else {
        _preparePaymentMethodSelection(options, supportedMethods);
        showConfirmation();
      }
    } catch (error, stackTrace) {
      debugPrint('[Membership] payment options failed: $error\n$stackTrace');
      // 支付方式接口不可用时，按空列表处理，走设备默认支付方式兜底。
      await _startPayment(plan, _defaultPaymentChannel);
    }
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

    final methodCode = state.selectedPaymentMethodCode;
    final methods = state.paymentMethods.where(
      (method) => method.methodCode == methodCode,
    );
    if (methods.isEmpty) {
      _markUnsupportedPayment();
      return;
    }
    await _startPayment(
      state.confirmationPlan!,
      methods.first.payChannel,
      paymentMethod: methods.first,
    );
  }

  void selectPaymentMethod(String methodCode) {
    if (state.purchaseStatus != MembershipPurchaseStatus.idle ||
        !state.paymentMethods.any(
          (method) => method.methodCode == methodCode,
        )) {
      return;
    }
    state = state.copyWith(selectedPaymentMethodCode: methodCode);
  }

  void _preparePaymentMethodSelection(
    PaymentMethodOptions options,
    List<PaymentMethodOption> methods,
  ) {
    final selected =
        methods.any((method) => method.methodCode == options.defaultMethodCode)
        ? options.defaultMethodCode
        : methods.first.methodCode;
    state = state.copyWith(
      paymentMethods: List<PaymentMethodOption>.unmodifiable(methods),
      selectedPaymentMethodCode: selected,
    );
  }

  Future<void> _startPayment(
    MembershipPlan plan,
    String payChannel, {
    PaymentMethodOption? paymentMethod,
  }) async {
    if (PayChannel.isGoogle(payChannel)) {
      await _startGooglePurchase(plan, paymentMethod: paymentMethod);
      return;
    }
    // Apple/三方支付入口预留：接入后在这里分别创建订单并调起对应 SDK。
    _markUnsupportedPayment();
  }

  Future<void> _startGooglePurchase(
    MembershipPlan plan, {
    PaymentMethodOption? paymentMethod,
  }) async {
    final purchaseGeneration = ++_purchaseGeneration;
    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    loading.show(label: PaymentLoadingLabel.loading);
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

      await Future<void>.delayed(_paymentSheetDismissDelay);
      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }

      loading.hide();
      await ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.paymentStart, {
              'payment_method_id': paymentMethod?.methodCode ?? 'google_play',
              'payment_method_type': PayChannel.analyticsPaymentMethodTypeFor(
                paymentMethod?.payChannel ?? PayChannel.google,
              ),
              'order_id': paymentOrder.orderNo,
              'product_id': plan.id,
              'product_type': 'vip_subscription',
            }),
          );
      final outcome = await ref
          .read(paymentPurchaseCoordinatorProvider)
          .executeGooglePurchase(
            iapService: iapService,
            order: paymentOrder,
            product: productDetails,
            isConsumable: false,
            productType: _membershipProductType,
            packageName: _packageName,
            onPhase: (phase) {
              state = state.copyWith(
                purchaseStatus: switch (phase) {
                  GooglePurchasePhase.waitingPayment =>
                    MembershipPurchaseStatus.waitingPayment,
                  GooglePurchasePhase.verifying =>
                    MembershipPurchaseStatus.verifying,
                },
              );
              if (phase == GooglePurchasePhase.verifying) loading.show();
            },
          );

      if (!_isCurrentPurchase(purchaseGeneration, plan.id)) {
        return;
      }
      if (outcome == GooglePurchaseOutcome.cancelled) {
        _markPurchaseCancelled(plan.id);
        return;
      }
      if (outcome == GooglePurchaseOutcome.pending) {
        state = state.copyWith(
          purchaseStatus: MembershipPurchaseStatus.pending,
        );
        return;
      }

      await _refreshAfterPurchase();

      // 支付已验证且权益已刷新后，再同步一次当前账号的通知状态。
      await ref
          .read(startupNotificationPermissionReporterProvider)
          .syncForAccount(ref.read(userInfoStoreProvider).showId);

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
    state = state.copyWith(
      purchaseStatus: MembershipPurchaseStatus.cancelled,
      clearConfirmation: true,
      clearError: true,
      clearPurchaseFailure: true,
    );
  }

  void _markUnsupportedPayment() {
    state = state.copyWith(
      purchaseStatus: MembershipPurchaseStatus.failed,
      purchaseFailureKind: MembershipPurchaseFailureKind.payment,
      clearError: true,
    );
  }

  Future<Map<String, ProductDetails>> _queryIapProducts(
    List<MembershipPlan> plans,
  ) async {
    final productIds = <String>{};
    for (final plan in plans) {
      if (!PayChannel.isGoogle(plan.payChannel)) {
        continue;
      }
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
    final priceService = iapDetails.isEmpty
        ? null
        : ref.read(iapPriceServiceProvider);
    return [
      for (final plan in plans)
        if (PayChannel.isOther(plan.payChannel))
          plan
        else if (PayChannel.isApple(plan.payChannel) &&
            defaultTargetPlatform == TargetPlatform.iOS)
          plan
        else if (PayChannel.isGoogle(plan.payChannel) &&
            iapDetails.containsKey(plan.platformProductId))
          _mergePlanPricing(
            plan,
            iapDetails[plan.platformProductId],
            priceService!,
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
      final promoCycles = promo['promoCycles'] as int?;
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
        promoCycles: promoCycles,
        hasFreeTrial: promo['hasFreeTrial'] as bool? ?? false,
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
    int? promoCycles,
    bool? hasFreeTrial,
    String? regularPeriodIso,
  }) {
    return MembershipPlan(
      id: plan.id,
      title: title ?? plan.title,
      priceLabel: priceLabel ?? plan.priceLabel,
      dailyPriceLabel: dailyPriceLabel ?? plan.dailyPriceLabel,
      period: plan.period,
      platformProductId: plan.platformProductId,
      payChannel: plan.payChannel,
      badgeLabel: plan.badgeLabel,
      originalPriceLabel: originalPriceLabel ?? plan.originalPriceLabel,
      promotionPriceLabel: promotionPriceLabel ?? plan.promotionPriceLabel,
      hasPromo: hasPromo ?? plan.hasPromo,
      regularPriceLabel: regularPriceLabel ?? plan.regularPriceLabel,
      promoCountdownEndMs: plan.promoCountdownEndMs,
      description: plan.description,
      enabled: plan.enabled,
      promoPeriodIso: promoPeriodIso ?? plan.promoPeriodIso,
      promoCycles: promoCycles ?? plan.promoCycles,
      hasFreeTrial: hasFreeTrial ?? plan.hasFreeTrial,
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
        state.purchaseStatus != MembershipPurchaseStatus.idle;
  }

  Future<PaymentMethodOptions> _fetchPaymentOptions(MembershipPlan plan) {
    return ref
        .read(payRepositoryProvider)
        .getPaymentOrderOptions(
          countryCode: ref.read(apiRegionCodeProvider),
          osType: _clientOsType,
          payScene: 2,
          productId: int.tryParse(plan.id) ?? 0,
          productType: _membershipProductType,
          scene: 'membership',
        );
  }

  List<PaymentMethodOption> _supportedPaymentMethods(
    List<PaymentMethodOption> methods,
  ) => [
    for (final method in methods)
      if (_isSupportedPaymentChannel(method.payChannel)) method,
  ];

  bool _isSupportedPaymentChannel(String payChannel) =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? PayChannel.isApple(payChannel)
      : PayChannel.isGoogle(payChannel);

  String get _defaultPaymentChannel =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? PayChannel.apple
      : PayChannel.google;

  int get _clientOsType => defaultTargetPlatform == TargetPlatform.iOS ? 1 : 2;
}
