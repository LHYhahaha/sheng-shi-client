import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../data/dto/payment_order_verify_request_dto.dart';
import '../data/remote/pay_remote_data_source.dart';

class IapPurchaseService {
  static const int maxGoogleApplicationUserNameLength = 64;

  IapPurchaseService({bool setup = true}) {
    if (setup) {
      _setup();
    }
  }

  InAppPurchase get _iap => InAppPurchase.instance;
  final _purchaseController = StreamController<PurchaseDetails>.broadcast();
  final _purchaseErrorController = StreamController<Object>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  PayRemoteDataSource? _payRemoteDataSource;

  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;
  Stream<Object> get purchaseErrorStream => _purchaseErrorController.stream;

  void _setup() {
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        debugPrint('[IapPurchase] purchaseStream error: $error');
        _notifyPurchaseError(error);
      },
    );
  }

  void initialize({required PayRemoteDataSource payRemoteDataSource}) {
    _payRemoteDataSource = payRemoteDataSource;
  }

  Future<Map<String, ProductDetails>> queryProducts({
    required Set<String> productIds,
  }) async {
    try {
      debugPrint('[IapPurchase] Querying products: $productIds');
      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('[IapPurchase] Product query failed: ${response.error}');
        return {};
      }

      final result = <String, ProductDetails>{};
      for (final product in response.productDetails) {
        result[product.id] = product;
        debugPrint(
          '[IapPurchase] Product found: ${product.id}, price: ${product.price}',
        );
      }

      debugPrint('[IapPurchase] Product query succeeded: ${result.length}');
      return result;
    } catch (e, st) {
      debugPrint('[IapPurchase] Product query exception: $e\n$st');
      return {};
    }
  }

  Future<int> restoreAndConsumePendingPurchases({
    required String source,
    Set<String>? productIds,
    Duration waitForCallbacks = const Duration(seconds: 3),
  }) async {
    final seenPurchaseKeys = <String>{};
    final consumeTasks = <Future<void>>[];
    StreamSubscription<PurchaseDetails>? sub;
    debugPrint('[IapPendingCleanup] restore start, source=$source');

    try {
      sub = purchaseStream.listen((details) {
        final purchaseToken =
            details.verificationData.serverVerificationData;
        final key = [
          details.productID,
          details.purchaseID,
          purchaseToken,
        ].join('|');
        if (!seenPurchaseKeys.add(key)) {
          return;
        }

        debugPrint('[IapPendingCleanup] ===== restored purchase =====');
        debugPrint('[IapPendingCleanup] source=$source');
        debugPrint('[IapPendingCleanup] productID=${details.productID}');
        debugPrint('[IapPendingCleanup] purchaseID=${details.purchaseID}');
        debugPrint('[IapPendingCleanup] status=${details.status}');
        debugPrint(
          '[IapPendingCleanup] pendingCompletePurchase=${details.pendingCompletePurchase}',
        );
        debugPrint(
          '[IapPendingCleanup] transactionDate=${details.transactionDate}',
        );
        debugPrint(
          '[IapPendingCleanup] verification.source=${details.verificationData.source}',
        );
        debugPrint('[IapPendingCleanup] purchaseToken=$purchaseToken');
        debugPrint('[IapPendingCleanup] =============================');

        final matchesRequestedProduct =
            productIds == null || productIds.contains(details.productID);
        final shouldConsume =
            matchesRequestedProduct &&
            (details.status == PurchaseStatus.purchased ||
                details.status == PurchaseStatus.restored);
        if (shouldConsume) {
          consumeTasks.add(consumePurchase(details));
        } else {
          debugPrint(
            '[IapPendingCleanup] skip restored purchase, '
            'source=$source, productID=${details.productID}, '
            'requestedProductIds=$productIds, status=${details.status}',
          );
        }
      });

      await _iap.restorePurchases();
      await Future<void>.delayed(waitForCallbacks);
      await Future.wait(consumeTasks);

      if (seenPurchaseKeys.isEmpty) {
        debugPrint(
          '[IapPendingCleanup] no restored purchase callbacks, source=$source',
        );
      }
      return consumeTasks.length;
    } catch (e, st) {
      debugPrint('[IapPendingCleanup] restore failed, source=$source: $e\n$st');
      return 0;
    } finally {
      await sub?.cancel();
      debugPrint('[IapPendingCleanup] restore end, source=$source');
    }
  }

  Future<bool> buyProduct({
    required ProductDetails product,
    bool isConsumable = false,
    String? offerToken,
    String? applicationUserName,
  }) async {
    try {
      final purchaseParam =
          Platform.isAndroid && offerToken != null && offerToken.isNotEmpty
          ? GooglePlayPurchaseParam(
              productDetails: product,
              applicationUserName: applicationUserName,
              offerToken: offerToken,
            )
          : PurchaseParam(
              productDetails: product,
              applicationUserName: applicationUserName,
            );

      if (isConsumable) {
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      return true;
    } catch (e) {
      debugPrint('[IapPurchase] Failed to launch payment: $e');
      _notifyPurchaseError(e);
      return false;
    }
  }

  String? buildOrderApplicationUserName({
    required String orderNo,
    String? clientOrderNo,
  }) {
    final normalizedOrderNo = orderNo.trim();
    final normalizedClientOrderNo = clientOrderNo?.trim();
    if (normalizedOrderNo.isEmpty) {
      return null;
    }

    final value =
        normalizedClientOrderNo == null || normalizedClientOrderNo.isEmpty
        ? 's:$normalizedOrderNo'
        : 'c:$normalizedClientOrderNo|s:$normalizedOrderNo';
    if (value.length > maxGoogleApplicationUserNameLength) {
      debugPrint(
        '[IapPurchase] order applicationUserName exceeds '
        '$maxGoogleApplicationUserNameLength chars: ${value.length}',
      );
    }
    return value;
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> detailsList) {
    for (final details in detailsList) {
      debugPrint(
        '[IapPurchase] purchase update: ${details.productID}, '
        'status: ${details.status}, '
        'pendingComplete: ${details.pendingCompletePurchase}',
      );

      if (details.status == PurchaseStatus.error &&
          details.pendingCompletePurchase) {
        _iap.completePurchase(details);
      }
      if (details.status == PurchaseStatus.error) {
        _notifyPurchaseError(
          details.error ??
              Exception(
                'IAP purchase error: productID=${details.productID}, '
                'status=${details.status}',
              ),
        );
      }

      _notifyPurchase(details);
    }
  }

  void _notifyPurchase(PurchaseDetails details) {
    if (!_purchaseController.isClosed) {
      _purchaseController.add(details);
    }
  }

  void _notifyPurchaseError(Object error) {
    if (!_purchaseErrorController.isClosed) {
      _purchaseErrorController.add(error);
    }
  }

  Future<bool> verifyGooglePayment({
    required String orderNo,
    required String channelProductId,
    required String packageName,
    required int productType,
    required String purchaseToken,
    String? channelOrderId,
    String? rawReceipt,
  }) async {
    try {
      if (_payRemoteDataSource == null) {
        debugPrint('[IapPurchase] Pay remote data source not initialized');
        return false;
      }

      final request = PaymentOrderVerifyRequestDto(
        orderNo: orderNo,
        channelOrderId: channelOrderId,
        channelProductId: channelProductId,
        packageName: packageName,
        productType: productType,
        purchaseToken: purchaseToken,
        rawReceipt: rawReceipt,
      );

      final response = await _payRemoteDataSource!.verifyGooglePayment(request);
      debugPrint('[IapPurchase] Payment verified: ${response.orderNo}');
      return true;
    } catch (e, st) {
      debugPrint('[IapPurchase] Payment verification failed: $e\n$st');
      return false;
    }
  }

  Future<void> completePurchase(PurchaseDetails details) async {
    try {
      await _iap.completePurchase(details);
      debugPrint('[IapPurchase] Purchase completed: ${details.productID}');
    } catch (e) {
      debugPrint('[IapPurchase] Failed to complete purchase: $e');
    }
  }

  Future<void> consumePurchase(PurchaseDetails details) async {
    try {
      if (Platform.isAndroid) {
        final androidAddition =
            _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await androidAddition.consumePurchase(details);
        debugPrint('[IapPurchase] Purchase consumed: ${details.productID}');
        return;
      }

      if (details.pendingCompletePurchase) {
        await completePurchase(details);
      }
    } catch (e) {
      debugPrint('[IapPurchase] Failed to consume purchase: $e');
    }
  }

  void dispose() {
    _purchaseSub?.cancel();
    _purchaseController.close();
    _purchaseErrorController.close();
  }
}
