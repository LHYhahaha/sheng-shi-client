import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/adjust/adjust_event_reporter_provider.dart';
import '../../../core/analytics/analytics_definition.dart';
import '../../../core/analytics/analytics_event.dart';
import '../../../core/analytics/analytics_provider.dart';
import '../../../core/auth/session_cleanup_types.dart';
import '../../../core/runtime/api_region_code_provider.dart';
import '../../entitlement/application/entitlement_controller.dart';
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
import '../data/store_repository_provider.dart';
import '../domain/store_package.dart';

final storeControllerProvider = NotifierProvider<StoreController, StoreState>(
  StoreController.new,
);

enum StorePurchaseStatus {
  idle,
  creatingOrder,
  waitingPayment,
  verifying,
  pending,
  success,
  failed,
  cancelled,
}

enum StorePurchaseFailureKind {
  paymentOptions,
  orderCreation,
  payment,
  verification,
}

class StoreState {
  const StoreState({
    required this.isLoading,
    required this.balance,
    required this.coinPackages,
    required this.vipPackages,
    required this.tips,
    required this.selectedPackageId,
    required this.confirmationPackageId,
    required this.purchaseStatus,
    required this.purchaseFailureKind,
    required this.iapProductDetails,
    required this.paymentMethods,
    required this.selectedPaymentMethodCode,
    this.error,
  });

  const StoreState.initial()
    : isLoading = true,
      balance = 0,
      coinPackages = const [],
      vipPackages = const [],
      tips = null,
      selectedPackageId = null,
      confirmationPackageId = null,
      purchaseStatus = StorePurchaseStatus.idle,
      purchaseFailureKind = null,
      iapProductDetails = const {},
      paymentMethods = const [],
      selectedPaymentMethodCode = null,
      error = null;

  final bool isLoading;
  final int balance;
  final List<StorePackage> coinPackages;
  final List<StorePackage> vipPackages;
  final StoreTips? tips;
  final String? selectedPackageId;
  final String? confirmationPackageId;
  final StorePurchaseStatus purchaseStatus;
  final StorePurchaseFailureKind? purchaseFailureKind;
  final Map<String, ProductDetails> iapProductDetails;
  final List<PaymentMethodOption> paymentMethods;
  final String? selectedPaymentMethodCode;
  final Object? error;

  List<StorePackage> get packages => [...coinPackages, ...vipPackages];

  StorePackage? get selectedPackage => packageById(selectedPackageId);

  StorePackage? get confirmationPackage => packageById(confirmationPackageId);

  bool get hasContent => !isLoading && error == null;

  StorePackage? packageById(String? id) {
    if (id == null) {
      return null;
    }

    for (final package in packages) {
      if (package.id == id) {
        return package;
      }
    }
    return null;
  }

  StoreState copyWith({
    bool? isLoading,
    int? balance,
    List<StorePackage>? coinPackages,
    List<StorePackage>? vipPackages,
    StoreTips? tips,
    String? selectedPackageId,
    String? confirmationPackageId,
    StorePurchaseStatus? purchaseStatus,
    StorePurchaseFailureKind? purchaseFailureKind,
    Map<String, ProductDetails>? iapProductDetails,
    List<PaymentMethodOption>? paymentMethods,
    String? selectedPaymentMethodCode,
    Object? error,
    bool clearError = false,
    bool clearConfirmation = false,
    bool clearPurchaseFailure = false,
  }) {
    return StoreState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      coinPackages: coinPackages ?? this.coinPackages,
      vipPackages: vipPackages ?? this.vipPackages,
      tips: tips ?? this.tips,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      confirmationPackageId: clearConfirmation
          ? null
          : confirmationPackageId ?? this.confirmationPackageId,
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

class StoreController extends Notifier<StoreState> {
  static const _packageName = 'com.novashort.shortdrama';
  static const _coinProductType = 1;
  static const _vipProductType = 2;
  static const _paymentSheetDismissDelay = Duration(milliseconds: 260);

  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  StoreState build() => const StoreState.initial();

  void resetForSessionCleanup(SessionCleanupReason reason) {
    ++_generation;
    ++_purchaseGeneration;
    state = const StoreState.initial();
  }

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearConfirmation: true,
    );

    try {
      final data = await ref.read(storeRepositoryProvider).fetchRechargeData();
      if (!_isCurrent(generation)) {
        return;
      }

      // Check whether the user is already a member.
      final isMember = ref.read(entitlementControllerProvider).isMember;
      // Hide VIP packages for existing members.
      final vipPackagesRaw = isMember ? <StorePackage>[] : data.vipPackages;
      final coinPackagesRaw = data.coinPackages;

      final channelProductIds = <String>{};
      for (final package in coinPackagesRaw) {
        if (!PayChannel.isGoogle(package.payChannel)) {
          continue;
        }
        final productId = package.platformProductId;
        if (productId != null && productId.isNotEmpty) {
          channelProductIds.add(productId);
        }
      }
      for (final package in vipPackagesRaw) {
        if (!PayChannel.isGoogle(package.payChannel)) {
          continue;
        }
        final productId = package.platformProductId;
        if (productId != null && productId.isNotEmpty) {
          channelProductIds.add(productId);
        }
      }

      var iapDetails = <String, ProductDetails>{};
      if (channelProductIds.isNotEmpty) {
        iapDetails = await ref
            .read(iapPriceServiceProvider)
            .queryProducts(productIds: channelProductIds);
      }

      if (!_isCurrent(generation)) {
        return;
      }

      final priceService = iapDetails.isEmpty
          ? null
          : ref.read(iapPriceServiceProvider);
      final coinPackages = _mergeIapPricing(
        coinPackagesRaw,
        iapDetails,
        priceService,
      );
      final vipPackages = _mergeIapPricing(
        vipPackagesRaw,
        iapDetails,
        priceService,
      );
      final selectedId = coinPackages.isNotEmpty
          ? coinPackages.first.id
          : vipPackages.isNotEmpty
          ? vipPackages.first.id
          : null;

      state = state.copyWith(
        isLoading: false,
        balance: data.balance,
        coinPackages: List<StorePackage>.unmodifiable(coinPackages),
        vipPackages: List<StorePackage>.unmodifiable(vipPackages),
        tips: data.tips,
        selectedPackageId: selectedId,
        iapProductDetails: iapDetails,
        clearError: true,
      );
    } catch (error, stackTrace) {
      debugPrint('[Store] load failed: $error\n$stackTrace');
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> retry() => load();

  void selectPackage(String id) {
    if (state.packageById(id) == null) {
      return;
    }
    state = state.copyWith(selectedPackageId: id);
  }

  /// 商品点击入口：先向服务端获取可用支付方式。
  ///
  /// 仅 Google Play 时直接进入既有 IAP 流程；存在其他渠道时再展示收银台。
  /// 返回 true 表示展示支付方式弹窗；false 表示已直接尝试拉起支付。
  Future<bool> selectPackageForPurchase(
    String id, {
    void Function(bool shouldShowCashier)? onPaymentActionResolved,
  }) async {
    selectPackage(id);
    final package = state.selectedPackage;
    if (package == null) {
      return false;
    }

    try {
      final options = await _fetchPaymentOptions(package);
      final supportedMethods = _supportedPaymentMethods(options.options);
      if (supportedMethods.isEmpty) {
        onPaymentActionResolved?.call(false);
        await _startPayment(package, _defaultPaymentChannel);
      } else if (supportedMethods.length == 1) {
        onPaymentActionResolved?.call(false);
        await _startPayment(
          package,
          supportedMethods.single.payChannel,
          paymentMethod: supportedMethods.single,
        );
      } else {
        _preparePaymentMethodSelection(options, supportedMethods);
        showConfirmation();
        onPaymentActionResolved?.call(true);
        return true;
      }
    } catch (error, stackTrace) {
      debugPrint('[Store] payment options failed: $error\n$stackTrace');
      // 支付方式接口不可用时，按空列表处理，走设备默认支付方式兜底。
      onPaymentActionResolved?.call(false);
      await _startPayment(package, _defaultPaymentChannel);
    }
    return false;
  }

  void showConfirmation() {
    final selectedPackage = state.selectedPackage;
    if (selectedPackage == null) {
      return;
    }

    _purchaseGeneration++;
    state = state.copyWith(
      confirmationPackageId: selectedPackage.id,
      purchaseStatus: StorePurchaseStatus.idle,
      clearError: true,
      clearPurchaseFailure: true,
    );
  }

  void hideConfirmation() {
    _purchaseGeneration++;
    state = state.copyWith(
      purchaseStatus: StorePurchaseStatus.idle,
      clearConfirmation: true,
      clearPurchaseFailure: true,
    );
  }

  Future<void> confirmPurchase() async {
    if (state.confirmationPackage == null ||
        state.purchaseStatus != StorePurchaseStatus.idle) {
      return;
    }

    final methodCode = state.selectedPaymentMethodCode;
    final method = state.paymentMethods.where(
      (method) => method.methodCode == methodCode,
    );
    if (method.isEmpty) {
      _markUnsupportedPayment();
      return;
    }
    await _startPayment(
      state.confirmationPackage!,
      method.first.payChannel,
      paymentMethod: method.first,
    );
  }

  void selectPaymentMethod(String methodCode) {
    if (state.purchaseStatus != StorePurchaseStatus.idle ||
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
    StorePackage package,
    String payChannel, {
    PaymentMethodOption? paymentMethod,
  }) async {
    if (PayChannel.isGoogle(payChannel)) {
      await _startGooglePurchase(package, paymentMethod: paymentMethod);
      return;
    }
    // Apple/三方支付入口预留：接入后在这里分别创建订单并调起对应 SDK。
    _markUnsupportedPayment();
  }

  Future<void> _startGooglePurchase(
    StorePackage package, {
    PaymentMethodOption? paymentMethod,
  }) async {
    final purchaseGeneration = ++_purchaseGeneration;
    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    loading.show(label: PaymentLoadingLabel.loading);
    try {
      final platformProductId = package.platformProductId;
      if (platformProductId == null || platformProductId.isEmpty) {
        throw Exception('Package has no platform product id: ${package.id}');
      }

      var productDetails = state.iapProductDetails[platformProductId];
      productDetails ??= await ref
          .read(iapPriceServiceProvider)
          .queryProduct(productId: platformProductId);
      if (productDetails == null) {
        throw Exception('Product details not found for $platformProductId');
      }
      final checkoutProduct = productDetails;

      state = state.copyWith(
        purchaseStatus: StorePurchaseStatus.creatingOrder,
        clearError: true,
        clearPurchaseFailure: true,
      );

      final productId = int.tryParse(package.id);
      if (productId == null || productId <= 0) {
        throw Exception('Invalid product id: ${package.id}');
      }

      final productType = _productTypeFor(package);
      await ref
          .read(iapPendingPurchaseCleanerProvider)
          .cleanupBeforeCreateOrder(
            source: 'store',
            productIds: package.isCoinPackage
                ? {productDetails.id}
                : const <String>{},
          );
      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
        return;
      }

      final payRepository = ref.read(payRepositoryProvider);
      final paymentOrder = await payRepository.createPaymentOrder(
        productId: productId,
        productType: productType,
        scene: package.isCoinPackage ? 'store_coin' : 'store_vip',
      );

      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
        return;
      }

      final iapService = ref.read(iapPurchaseServiceProvider);
      if (iapService == null) {
        throw Exception('IAP purchase service not available');
      }
      await Future<void>.delayed(_paymentSheetDismissDelay);
      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
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
              'product_id': package.id,
              'product_type': _analyticsProductTypeFor(package),
            }),
          );
      final outcome = await ref
          .read(paymentPurchaseCoordinatorProvider)
          .executeGooglePurchase(
            iapService: iapService,
            order: paymentOrder,
            product: productDetails,
            isConsumable: package.isCoinPackage,
            productType: productType,
            packageName: _packageName,
            onGooglePlayCheckoutStarted: () {
              ref
                  .read(adjustEventReporterProvider)
                  .reportCheckoutStart(
                    productType: _analyticsProductTypeFor(package),
                    productId: package.id,
                    price: checkoutProduct.rawPrice,
                    currency: checkoutProduct.currencyCode,
                  );
            },
            onPhase: (phase) {
              state = state.copyWith(
                purchaseStatus: switch (phase) {
                  GooglePurchasePhase.waitingPayment =>
                    StorePurchaseStatus.waitingPayment,
                  GooglePurchasePhase.verifying =>
                    StorePurchaseStatus.verifying,
                },
              );
              if (phase == GooglePurchasePhase.verifying) loading.show();
            },
          );

      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
        return;
      }
      if (outcome == GooglePurchaseOutcome.cancelled) {
        _markPurchaseCancelled(package.id);
        return;
      }
      if (outcome == GooglePurchaseOutcome.pending) {
        state = state.copyWith(purchaseStatus: StorePurchaseStatus.pending);
        return;
      }

      await ref.read(entitlementControllerProvider.notifier).load();

      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
        return;
      }

      state = state.copyWith(purchaseStatus: StorePurchaseStatus.success);
    } catch (error, stackTrace) {
      debugPrint('[Store] purchase failed: $error\n$stackTrace');
      if (purchaseGeneration == _purchaseGeneration) {
        final failureKind = switch (state.purchaseStatus) {
          StorePurchaseStatus.creatingOrder =>
            StorePurchaseFailureKind.orderCreation,
          StorePurchaseStatus.verifying =>
            StorePurchaseFailureKind.verification,
          _ => StorePurchaseFailureKind.payment,
        };
        state = state.copyWith(
          purchaseStatus: StorePurchaseStatus.failed,
          purchaseFailureKind: failureKind,
          clearError: true,
        );
      }
    } finally {
      loading.hide();
    }
  }

  String _analyticsProductTypeFor(StorePackage package) {
    if (package.isCoinPackage) {
      return 'coin';
    }
    return package.productType == 'subscription'
        ? 'vip_subscription'
        : 'vip_once';
  }

  void cancelPurchase() {
    if (state.purchaseStatus != StorePurchaseStatus.idle) {
      return;
    }
    state = state.copyWith(purchaseStatus: StorePurchaseStatus.cancelled);
  }

  void _markPurchaseCancelled(String packageId) {
    state = state.copyWith(
      purchaseStatus: StorePurchaseStatus.cancelled,
      clearConfirmation: true,
      clearError: true,
      clearPurchaseFailure: true,
    );
  }

  void _markUnsupportedPayment() {
    state = state.copyWith(
      purchaseStatus: StorePurchaseStatus.failed,
      purchaseFailureKind: StorePurchaseFailureKind.payment,
      clearError: true,
    );
  }

  bool _isCurrent(int generation) => generation == _generation;

  int _productTypeFor(StorePackage package) =>
      package.isCoinPackage ? _coinProductType : _vipProductType;

  List<StorePackage> _mergeIapPricing(
    List<StorePackage> packages,
    Map<String, ProductDetails> iapDetails,
    IapPriceService? priceService,
  ) {
    return [
      for (final package in packages)
        if (PayChannel.isOther(package.payChannel))
          package
        else if (PayChannel.isApple(package.payChannel) &&
            defaultTargetPlatform == TargetPlatform.iOS)
          package
        else if (PayChannel.isGoogle(package.payChannel) &&
            iapDetails.containsKey(package.platformProductId))
          _mergePackagePricing(
            package,
            iapDetails[package.platformProductId],
            priceService!,
          ),
    ];
  }

  StorePackage _mergePackagePricing(
    StorePackage package,
    ProductDetails? product,
    IapPriceService priceService,
  ) {
    if (product == null) {
      return package;
    }

    if (package.isCoinPackage) {
      return package.copyWith(
        priceLabel: product.price,
        priceMicros: (product.rawPrice * 1000000).toInt(),
        currencyCode: product.currencyCode,
      );
    }

    final promo = priceService.extractPromoInfo(product);
    final hasPromo = promo?['hasPromo'] == true;
    if (!hasPromo) {
      return package.copyWith(
        priceLabel: product.price,
        priceMicros: (product.rawPrice * 1000000).toInt(),
        currencyCode: product.currencyCode,
        promotionExpireSeconds: 0,
      );
    }

    final promoPrice = promo?['promoPrice'] as String? ?? product.price;
    final regularPrice = promo?['regularPrice'] as String?;
    final promoMicros = promo?['promoPriceMicros'] as int?;
    final regularMicros = promo?['regularPriceMicros'] as int?;
    final backendCountdown = package.promotionExpireSeconds;
    final countdownSeconds = backendCountdown > 0 ? backendCountdown : 3600;

    return package.copyWith(
      priceLabel: promoPrice,
      originalPriceLabel: regularPrice ?? package.originalPriceLabel,
      priceMicros: promoMicros ?? (product.rawPrice * 1000000).toInt(),
      originalPriceMicros: regularMicros,
      currencyCode: product.currencyCode,
      basePlanId: promo?['basePlanId'] as String?,
      offerId: promo?['offerId'] as String?,
      badgeLabel: 'Promotion',
      promotionExpiresAt: DateTime.now().add(
        Duration(seconds: countdownSeconds),
      ),
      promotionExpireSeconds: countdownSeconds,
    );
  }

  bool _isCurrentPurchase(int purchaseGeneration, String packageId) {
    return purchaseGeneration == _purchaseGeneration &&
        state.purchaseStatus != StorePurchaseStatus.idle;
  }

  Future<PaymentMethodOptions> _fetchPaymentOptions(StorePackage package) {
    return ref
        .read(payRepositoryProvider)
        .getPaymentOrderOptions(
          countryCode: ref.read(apiRegionCodeProvider),
          osType: _clientOsType,
          payScene: package.isCoinPackage ? 1 : 2,
          productId: int.tryParse(package.id) ?? 0,
          productType: _productTypeFor(package),
          scene: package.isCoinPackage ? 'store_coin' : 'store_vip',
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
