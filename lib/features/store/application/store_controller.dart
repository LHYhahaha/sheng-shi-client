import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/auth/session_cleanup_types.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/application/iap_pending_purchase_cleaner.dart';
import '../../pay/application/iap_price_service.dart';
import '../../pay/application/payment_loading_controller.dart';
import '../../pay/provider/iap_price_service_provider.dart';
import '../../pay/provider/iap_purchase_service_provider.dart';
import '../../pay/provider/pay_repository_provider.dart';
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

enum StorePurchaseFailureKind { orderCreation, payment, verification }

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
      error: clearError ? null : error ?? this.error,
    );
  }
}

class StoreController extends Notifier<StoreState> {
  static const _packageName = 'com.novashort.shortdrama';
  static const _coinProductType = 1;
  static const _vipProductType = 2;
  static const _purchaseResultTimeout = Duration(seconds: 30);
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
        final productId = package.platformProductId;
        if (productId != null && productId.isNotEmpty) {
          channelProductIds.add(productId);
        }
      }
      for (final package in vipPackagesRaw) {
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

      final selectedId = coinPackagesRaw.isNotEmpty
          ? coinPackagesRaw.first.id
          : vipPackagesRaw.isNotEmpty
          ? vipPackagesRaw.first.id
          : null;

      final priceService = ref.read(iapPriceServiceProvider);
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

    final purchaseGeneration = _purchaseGeneration;
    final package = state.confirmationPackage!;
    StreamSubscription<PurchaseDetails>? sub;
    StreamSubscription<Object>? errorSub;
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
      final googleApplicationUserName =
          iapService.buildOrderApplicationUserName(
        orderNo: paymentOrder.orderNo,
        clientOrderNo: paymentOrder.clientOrderNo,
      );

      final completer = Completer<PurchaseDetails?>();
      sub = iapService.purchaseStream.listen((details) {
        final isCurrentProduct = details.productID == productDetails!.id;
        final isPurchaseError = details.status == PurchaseStatus.error;
        final isCancellation =
            details.status.name == 'canceled' ||
            details.status == PurchaseStatus.error &&
                _isUserCancelledPurchase(details);
        if ((isCurrentProduct || isCancellation || isPurchaseError) &&
            !completer.isCompleted) {
          completer.complete(details);
        }
      });
      errorSub = iapService.purchaseErrorStream.listen((error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      });

      state = state.copyWith(
        purchaseStatus: StorePurchaseStatus.waitingPayment,
      );
      await Future<void>.delayed(_paymentSheetDismissDelay);
      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
        return;
      }

      loading.hide();
      final started = await iapService.buyProduct(
        product: productDetails,
        isConsumable: package.isCoinPackage,
        applicationUserName: googleApplicationUserName,
      );
      if (!started) {
        throw Exception('Failed to launch IAP purchase');
      }

      final purchaseDetails = await completer.future.timeout(
        _purchaseResultTimeout,
        onTimeout: () {
          debugPrint('[Store] purchase result timed out.');
          return null;
        },
      );

      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
        return;
      }
      if (purchaseDetails == null) {
        _markPurchaseCancelled(package.id);
        return;
      }

      if (purchaseDetails.status == PurchaseStatus.pending) {
        state = state.copyWith(purchaseStatus: StorePurchaseStatus.pending);
        return;
      }
      if (purchaseDetails.status == PurchaseStatus.error) {
        if (_isUserCancelledPurchase(purchaseDetails)) {
          _markPurchaseCancelled(package.id);
          return;
        }
        throw Exception('Purchase failed: ${purchaseDetails.error}');
      }
      if (purchaseDetails.status.name == 'canceled') {
        _markPurchaseCancelled(package.id);
        return;
      }
      if (purchaseDetails.status != PurchaseStatus.purchased &&
          purchaseDetails.status != PurchaseStatus.restored) {
        throw Exception(
          'Unsupported purchase status: ${purchaseDetails.status}',
        );
      }
      state = state.copyWith(purchaseStatus: StorePurchaseStatus.verifying);
      loading.show();
      final verifyResult = await payRepository.verifyGooglePayment(
        orderNo: paymentOrder.orderNo,
        channelProductId: purchaseDetails.productID,
        packageName: _packageName,
        productType: productType,
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
        channelOrderId: purchaseDetails.purchaseID,
        rawReceipt: purchaseDetails.verificationData.source,
      );

      if (!_isCurrentPurchase(purchaseGeneration, package.id)) {
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
      await sub?.cancel();
      await errorSub?.cancel();
      loading.hide();
    }
  }

  void cancelPurchase() {
    if (state.purchaseStatus != StorePurchaseStatus.idle) {
      return;
    }
    state = state.copyWith(purchaseStatus: StorePurchaseStatus.cancelled);
  }

  void _markPurchaseCancelled(String packageId) {
    if (state.confirmationPackageId != packageId) {
      return;
    }
    state = state.copyWith(
      purchaseStatus: StorePurchaseStatus.cancelled,
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

  bool _isCurrent(int generation) => generation == _generation;

  int _productTypeFor(StorePackage package) =>
      package.isCoinPackage ? _coinProductType : _vipProductType;

  List<StorePackage> _mergeIapPricing(
    List<StorePackage> packages,
    Map<String, ProductDetails> iapDetails,
    IapPriceService priceService,
  ) {
    return [
      for (final package in packages)
        _mergePackagePricing(
          package,
          iapDetails[package.platformProductId],
          priceService,
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
        state.confirmationPackageId == packageId &&
        state.purchaseStatus != StorePurchaseStatus.idle;
  }
}
