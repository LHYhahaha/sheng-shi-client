import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../data/dto/payment_order_verify_request_dto.dart';
import '../data/remote/pay_remote_data_source.dart';

/// IAP 购买服务（公共）
///
/// 负责调起 Google Play / App Store 购买、监听购买结果、调用服务端验单。
/// Store 页面和 Membership 页面都可以使用这个服务。
class IapPurchaseService {
  static const int maxGoogleApplicationUserNameLength = 64;

  IapPurchaseService({bool setup = true}) {
    if (setup) {
      _setup();
    }
  }

  InAppPurchase get _iap => InAppPurchase.instance;
  final _purchaseController = StreamController<PurchaseDetails>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  PayRemoteDataSource? _payRemoteDataSource;

  /// 购买结果流
  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  /// 初始化 IAP，监听购买回调
  void _setup() {
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        debugPrint('[IapPurchase] purchaseStream error: $error');
      },
    );
  }

  /// 初始化远程数据源（需要在使用购买功能前调用）
  void initialize({required PayRemoteDataSource payRemoteDataSource}) {
    _payRemoteDataSource = payRemoteDataSource;
  }

  /// 查询商品信息
  Future<Map<String, ProductDetails>> queryProducts({
    required Set<String> productIds,
  }) async {
    try {
      debugPrint('[IapPurchase] 开始查询商品: $productIds');
      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('[IapPurchase] 查询商品失败: ${response.error}');
        return {};
      }

      final result = <String, ProductDetails>{};
      for (final product in response.productDetails) {
        result[product.id] = product;
        debugPrint(
          '[IapPurchase] 查询到商品: ${product.id}, price: ${product.price}',
        );
      }

      debugPrint('[IapPurchase] 查询成功: ${result.length} 个商品');
      return result;
    } catch (e, st) {
      debugPrint('[IapPurchase] 查询商品异常: $e\n$st');
      return {};
    }
  }

  /// 调起购买（根据商品类型自动选择 buyNonConsumable 或 buyConsumable）
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
        // 消耗型商品（金币）
        await _iap.buyConsumable(purchaseParam: purchaseParam);
      } else {
        // 订阅型商品（会员）
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      return true;
    } catch (e) {
      debugPrint('[IapPurchase] 调起支付失败: $e');
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

  /// 处理购买回调
  void _handlePurchaseUpdates(List<PurchaseDetails> detailsList) {
    for (final details in detailsList) {
      debugPrint(
        '[IapPurchase] 购买回调: ${details.productID}, '
        'status: ${details.status}, '
        'pending: ${details.pendingCompletePurchase}',
      );

      if (details.status == PurchaseStatus.pending) {
        // 等待支付完成
        debugPrint('[IapPurchase] 支付处理中...');
      } else if (details.status == PurchaseStatus.error) {
        debugPrint('[IapPurchase] 支付失败: ${details.error}');
        if (details.pendingCompletePurchase) {
          _iap.completePurchase(details);
        }
      } else if (details.status == PurchaseStatus.purchased ||
          details.status == PurchaseStatus.restored) {
        // 支付成功或恢复
        debugPrint(
          '[IapPurchase] 支付成功: ${details.productID}, '
          'purchaseID: ${details.purchaseID}',
        );

        // 通知监听器
        _notifyPurchase(details);
        continue;
      }

      // 通知监听器
      _notifyPurchase(details);
    }
  }

  /// 通知购买结果
  void _notifyPurchase(PurchaseDetails details) {
    if (!_purchaseController.isClosed) {
      _purchaseController.add(details);
    }
  }

  /// 验证谷歌支付订单
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
        debugPrint('[IapPurchase] 远程数据源未初始化');
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
      debugPrint('[IapPurchase] 验单成功: ${response.orderNo}');
      return true;
    } catch (e, st) {
      debugPrint('[IapPurchase] 验单失败: $e\n$st');
      return false;
    }
  }

  /// 完成购买（标记购买已完成）
  Future<void> completePurchase(PurchaseDetails details) async {
    try {
      await _iap.completePurchase(details);
      debugPrint('[IapPurchase] 购买已完成: ${details.productID}');
    } catch (e) {
      debugPrint('[IapPurchase] 完成购买失败: $e');
    }
  }

  /// 清理资源
  void dispose() {
    _purchaseSub?.cancel();
    _purchaseController.close();
  }
}
