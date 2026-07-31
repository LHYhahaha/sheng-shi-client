import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../entitlement/application/entitlement_controller.dart';
import '../../../core/runtime/api_region_code_provider.dart';
import '../../pay/application/iap_pending_purchase_cleaner.dart';
import '../../pay/application/payment_loading_controller.dart';
import '../../pay/provider/iap_purchase_service_provider.dart';
import '../../pay/provider/pay_repository_provider.dart';
import '../../pay/domain/pay_channel.dart';
import '../../pay/domain/payment_method_options.dart';
import '../application/player_feed_controller.dart';
import '../data/player_recharge_unlock_repository_provider.dart';
import '../domain/player_recharge_unlock_offer.dart';

/// 促销倒计时结束时间缓存。
///
/// 每次打开弹窗都会重新写入结束时间，满足“进页面重新倒计时”的展示规则。
final _promotionEndTimesCache = <String, DateTime>{};

final playerRechargeUnlockControllerProvider =
    NotifierProvider.family<
      PlayerRechargeUnlockController,
      PlayerRechargeUnlockState,
      String
    >(PlayerRechargeUnlockController.new);

enum PlayerRechargeUnlockStatus {
  idle,
  loading,
  selectedCoinPackage,
  selectedMembershipPackage,
  processing,
  success,
  cancelled,
  failed,
}

enum PlayerRechargePaymentStage { creatingOrder, waitingPayment, verifying }

enum PlayerRechargePurchaseFailureKind {
  paymentOptions,
  orderCreation,
  payment,
  verification,
}

/// 播放器内 entitlement 充值解锁状态。
///
/// 这不是播放器真实播放状态，也不是 Store 订单状态。它只管理 locked episode 金币不足
/// 时的弹窗展示和 remote purchase 流程，成功后再通知 PlayerPage 继续 pending unlock。
class PlayerRechargeUnlockState {
  const PlayerRechargeUnlockState({
    required this.status,
    this.itemId,
    this.offer,
    this.selectedCoinPackageId,
    this.selectedMembershipPackageId,
    this.paymentStage,
    this.purchaseFailureKind,
    this.error,
  });

  const PlayerRechargeUnlockState.initial()
    : status = PlayerRechargeUnlockStatus.idle,
      itemId = null,
      offer = null,
      selectedCoinPackageId = null,
      selectedMembershipPackageId = null,
      paymentStage = null,
      purchaseFailureKind = null,
      error = null;

  final PlayerRechargeUnlockStatus status;
  final String? itemId;
  final PlayerRechargeUnlockOffer? offer;
  final String? selectedCoinPackageId;
  final String? selectedMembershipPackageId;
  final PlayerRechargePaymentStage? paymentStage;
  final PlayerRechargePurchaseFailureKind? purchaseFailureKind;
  final Object? error;

  bool get isProcessing => status == PlayerRechargeUnlockStatus.processing;

  PlayerRechargeCoinPackage? get selectedCoinPackage {
    final packageId = selectedCoinPackageId;
    final currentOffer = offer;
    if (packageId == null || currentOffer == null) {
      return null;
    }
    for (final package in currentOffer.coinPackages) {
      if (package.id == packageId) {
        return package;
      }
    }
    return null;
  }

  PlayerRechargeMembershipPackage? get selectedMembershipPackage {
    final packageId = selectedMembershipPackageId;
    final currentOffer = offer;
    if (packageId == null || currentOffer == null) {
      return null;
    }
    for (final package in currentOffer.membershipPackages) {
      if (package.id == packageId) {
        return package;
      }
    }
    return null;
  }

  PlayerRechargeUnlockState copyWith({
    PlayerRechargeUnlockStatus? status,
    String? itemId,
    PlayerRechargeUnlockOffer? offer,
    String? selectedCoinPackageId,
    String? selectedMembershipPackageId,
    PlayerRechargePaymentStage? paymentStage,
    PlayerRechargePurchaseFailureKind? purchaseFailureKind,
    Object? error,
    bool clearSelection = false,
    bool clearPaymentStage = false,
    bool clearPurchaseFailure = false,
    bool clearError = false,
  }) {
    return PlayerRechargeUnlockState(
      status: status ?? this.status,
      itemId: itemId ?? this.itemId,
      offer: offer ?? this.offer,
      selectedCoinPackageId: clearSelection
          ? null
          : selectedCoinPackageId ?? this.selectedCoinPackageId,
      selectedMembershipPackageId: clearSelection
          ? null
          : selectedMembershipPackageId ?? this.selectedMembershipPackageId,
      paymentStage: clearPaymentStage
          ? null
          : paymentStage ?? this.paymentStage,
      purchaseFailureKind: clearPurchaseFailure
          ? null
          : purchaseFailureKind ?? this.purchaseFailureKind,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Entitlement 解锁充值弹窗控制器。
///
/// 控制器只处理"金币不足且非会员时展示充值/会员组合弹窗"的 mock 流程，不触碰
/// media session，也不发放真实金币/会员。真实支付接入时，processing 后必须等待
/// 服务端验单和 entitlement 刷新，再由调用方决定是否继续播放 locked episode。
class PlayerRechargeUnlockController
    extends Notifier<PlayerRechargeUnlockState> {
  PlayerRechargeUnlockController(this.sessionKey);

  static const _packageName = 'com.yushi.drama.client';
  static const _coinProductType = 1;
  static const _membershipProductType = 2;
  static const _purchaseResultTimeout = Duration(seconds: 30);
  static const _paymentSheetDismissDelay = Duration(milliseconds: 260);

  final String sessionKey;
  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  PlayerRechargeUnlockState build() {
    ref.onDispose(() {
      // open() 会按最新商品数据重置倒计时；这里不做额外清理。
    });
    return const PlayerRechargeUnlockState.initial();
  }

  Future<void> open({
    required String itemId,
    required int requiredCoins,
  }) async {
    final generation = ++_generation;
    _purchaseGeneration++;

    // 检查用户是否已是会员
    final isMember = ref.read(entitlementControllerProvider).isMember;

    state = PlayerRechargeUnlockState(
      status: PlayerRechargeUnlockStatus.loading,
      itemId: itemId,
      offer: null,
      selectedCoinPackageId: null,
      selectedMembershipPackageId: null,
      paymentStage: null,
      purchaseFailureKind: null,
    );

    try {
      final offer = await ref
          .read(playerRechargeUnlockRepositoryProvider)
          .fetchOffer(
            itemId: itemId,
            requiredCoins: requiredCoins,
            isMember: isMember,
          );
      if (!_isCurrent(generation)) {
        return;
      }
      // 初始化促销倒计时结束时间
      _initPromotionEndTimes(offer);

      state = PlayerRechargeUnlockState(
        status: PlayerRechargeUnlockStatus.idle,
        itemId: itemId,
        offer: offer,
        selectedCoinPackageId: null,
        selectedMembershipPackageId: null,
        paymentStage: null,
        purchaseFailureKind: null,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerRechargeUnlockStatus.failed,
        purchaseFailureKind: PlayerRechargePurchaseFailureKind.paymentOptions,
        error: error,
      );
    }
  }

  Future<void> selectCoinPackage(String packageId) {
    if (state.isProcessing || state.offer == null) {
      return Future<void>.value();
    }
    if (!state.offer!.coinPackages.any((package) => package.id == packageId)) {
      return Future<void>.value();
    }
    state = state.copyWith(
      status: PlayerRechargeUnlockStatus.selectedCoinPackage,
      selectedCoinPackageId: packageId,
      selectedMembershipPackageId: null,
      clearPaymentStage: true,
      clearPurchaseFailure: true,
      clearError: true,
    );
    return _startRemotePurchase();
  }

  /// 商品卡片点击入口：先由服务端决定可用支付方式。
  ///
  /// 返回 true 表示需展示应用内购买确认弹框；仅 Google Play 时已直接拉起 IAP。
  Future<bool> prepareCoinPackagePurchase(String packageId) =>
      _preparePackagePurchase(packageId, isCoinPackage: true);

  /// 商品卡片点击入口：先由服务端决定可用支付方式。
  Future<bool> prepareMembershipPackagePurchase(String packageId) =>
      _preparePackagePurchase(packageId, isCoinPackage: false);

  Future<bool> _preparePackagePurchase(
    String packageId, {
    required bool isCoinPackage,
  }) async {
    final offer = state.offer;
    final exists = isCoinPackage
        ? offer?.coinPackages.any((package) => package.id == packageId) == true
        : offer?.membershipPackages.any((package) => package.id == packageId) ==
              true;
    if (state.isProcessing || !exists) {
      return false;
    }

    try {
      final options = await ref
          .read(payRepositoryProvider)
          .getPaymentOrderOptions(
            countryCode: ref.read(apiRegionCodeProvider),
            dramaId: int.tryParse(state.itemId ?? ''),
            osType: _clientOsType,
            payScene: isCoinPackage ? 1 : 2,
            productId: int.tryParse(packageId) ?? 0,
            productType: isCoinPackage
                ? _coinProductType
                : _membershipProductType,
            scene: isCoinPackage ? 'player_coin' : 'player_membership',
          );
      if (!_isGoogleOnly(options)) {
        return true;
      }
      if (isCoinPackage) {
        await selectCoinPackage(packageId);
      } else {
        await selectMembershipPackage(packageId);
      }
    } catch (error) {
      state = state.copyWith(
        status: PlayerRechargeUnlockStatus.failed,
        error: error,
      );
    }
    return false;
  }

  Future<void> selectMembershipPackage(String packageId) {
    if (state.isProcessing || state.offer == null) {
      return Future<void>.value();
    }
    if (!state.offer!.membershipPackages.any(
      (package) => package.id == packageId,
    )) {
      return Future<void>.value();
    }
    state = state.copyWith(
      status: PlayerRechargeUnlockStatus.selectedMembershipPackage,
      selectedCoinPackageId: null,
      selectedMembershipPackageId: packageId,
      clearPaymentStage: true,
      clearPurchaseFailure: true,
      clearError: true,
    );
    return _startRemotePurchase();
  }

  void close() {
    _purchaseGeneration++;
    state = state.copyWith(
      status: PlayerRechargeUnlockStatus.cancelled,
      clearPaymentStage: true,
      clearPurchaseFailure: true,
      clearError: true,
    );
  }

  void resetForSessionCleanup() {
    ++_generation;
    ++_purchaseGeneration;
    _promotionEndTimesCache.clear();
    state = const PlayerRechargeUnlockState.initial();
  }

  /// 初始化促销倒计时结束时间
  ///
  /// 每次打开弹窗都以当前时间重新计算结束时间。
  void _initPromotionEndTimes(PlayerRechargeUnlockOffer offer) {
    for (final pkg in offer.membershipPackages) {
      if (pkg.promotionExpireSeconds > 0) {
        _promotionEndTimesCache[pkg.id] = DateTime.now().add(
          Duration(seconds: pkg.promotionExpireSeconds),
        );
      } else {
        // 非促销套餐，移除缓存
        _promotionEndTimesCache.remove(pkg.id);
      }
    }
  }

  /// 获取指定套餐的促销剩余秒数
  ///
  /// 基于 [_promotionEndTimesCache] 中的结束时间动态计算。
  int getPromotionRemainingSeconds(String packageId) {
    final endTime = _promotionEndTimesCache[packageId];
    if (endTime == null) return 0;
    final remaining = endTime.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _startRemotePurchase() async {
    final purchaseGeneration = ++_purchaseGeneration;
    state = state.copyWith(
      status: PlayerRechargeUnlockStatus.processing,
      paymentStage: PlayerRechargePaymentStage.creatingOrder,
      clearPurchaseFailure: true,
    );

    StreamSubscription<PurchaseDetails>? sub;
    StreamSubscription<Object>? errorSub;
    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    loading.show(label: PaymentLoadingLabel.loading);
    try {
      // 获取选中的套餐
      final selectedCoinPackage = state.selectedCoinPackage;
      final selectedMembershipPackage = state.selectedMembershipPackage;

      if (selectedCoinPackage == null && selectedMembershipPackage == null) {
        throw Exception('No package selected');
      }

      // 2. 准备创建订单的参数
      final isCoinPackage = selectedCoinPackage != null;
      final packageId = isCoinPackage
          ? selectedCoinPackage.id
          : selectedMembershipPackage!.id;
      final productId = int.tryParse(packageId) ?? 0;
      final productType = isCoinPackage
          ? _coinProductType
          : _membershipProductType;

      if (productId == 0) {
        throw Exception('Invalid productId: $packageId');
      }
      final selectedIapInfo = isCoinPackage
          ? selectedCoinPackage.iapInfo
          : selectedMembershipPackage!.iapInfo;
      final selectedProductDetails = selectedIapInfo?.productDetails;

      // 3. 创建订单
      debugPrint('[PlayerRecharge] 开始创建订单: productId=$productId');

      await ref
          .read(iapPendingPurchaseCleanerProvider)
          .cleanupBeforeCreateOrder(
            source: 'player_recharge',
            productIds: isCoinPackage && selectedProductDetails != null
                ? {selectedProductDetails.id}
                : const <String>{},
          );
      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      final order = await ref
          .read(payRepositoryProvider)
          .createPaymentOrder(
            productId: productId,
            productType: productType,
            scene: isCoinPackage ? 'player_coin' : 'player_membership',
            shortId: int.tryParse(state.itemId ?? ''),
          );

      debugPrint(
        '[PlayerRecharge] 订单创建成功: orderNo=${order.orderNo}, clientOrderNo=${order.clientOrderNo}',
      );

      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      // 4. 获取 IAP 购买服务
      state = state.copyWith(
        paymentStage: PlayerRechargePaymentStage.waitingPayment,
      );
      await Future<void>.delayed(_paymentSheetDismissDelay);
      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      final iapService = ref.read(iapPurchaseServiceProvider);
      if (iapService == null) {
        throw Exception('IAP purchase service not available');
      }

      // 5. 从 iapInfo 中获取商品详情和 offerToken（无需重复查询 IAP）
      final iapInfo = isCoinPackage
          ? selectedCoinPackage.iapInfo
          : selectedMembershipPackage!.iapInfo;

      final productDetails = selectedProductDetails;
      if (productDetails == null) {
        throw Exception('IAP product details not found in iapInfo');
      }

      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      // 6. 设置 Completer 等待购买结果
      final completer = Completer<PurchaseDetails?>();

      sub = iapService.purchaseStream.listen((details) {
        final isCurrentProduct = details.productID == productDetails.id;
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

      // 7. 调起 IAP 购买
      final isConsumable = isCoinPackage;

      // 对于订阅商品，从 iapInfo 中获取 offerToken
      String? offerToken;
      if (!isConsumable) {
        offerToken = iapInfo?.offerToken;
        debugPrint('[PlayerRecharge] 使用 offerToken: $offerToken');
      }

      loading.hide();
      final started = await iapService.buyProduct(
        product: productDetails,
        isConsumable: isConsumable,
        offerToken: offerToken,
        applicationUserName: iapService.buildOrderApplicationUserName(
          orderNo: order.orderNo,
          clientOrderNo: order.clientOrderNo,
        ),
      );
      if (!started) {
        throw Exception('Failed to launch IAP purchase');
      }

      // 8. 等待购买结果（设置超时）
      final purchaseDetails = await completer.future.timeout(
        _purchaseResultTimeout,
        onTimeout: () {
          debugPrint('[PlayerRecharge] purchase result timed out');
          return null;
        },
      );

      // 9. 检查是否仍在处理中
      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      // 10. 处理购买结果
      if (purchaseDetails == null) {
        _markPurchaseCancelled();
        return;
      }

      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('[PlayerRecharge] purchase pending');
        return;
      }
      if (purchaseDetails.status == PurchaseStatus.error) {
        if (_isUserCancelledPurchase(purchaseDetails)) {
          _markPurchaseCancelled();
          return;
        }
        throw Exception('Purchase failed: ${purchaseDetails.error}');
      }
      if (purchaseDetails.status.name == 'canceled') {
        _markPurchaseCancelled();
        return;
      }
      if (purchaseDetails.status != PurchaseStatus.purchased &&
          purchaseDetails.status != PurchaseStatus.restored) {
        throw Exception(
          'Unsupported purchase status: ${purchaseDetails.status}',
        );
      }

      state = state.copyWith(
        paymentStage: PlayerRechargePaymentStage.verifying,
      );
      loading.show();
      debugPrint('[PlayerRecharge] purchase success, verifying order');
      final verifyResult = await ref
          .read(payRepositoryProvider)
          .verifyGooglePayment(
            orderNo: order.orderNo,
            channelProductId: purchaseDetails.productID,
            packageName: _packageName,
            productType: productType,
            purchaseToken:
                purchaseDetails.verificationData.serverVerificationData,
            channelOrderId: purchaseDetails.purchaseID,
            rawReceipt: purchaseDetails.verificationData.source,
          );

      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
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

      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      state = state.copyWith(status: PlayerRechargeUnlockStatus.success);
      debugPrint(
        '[PlayerRecharge] purchase verified and entitlement refreshed',
      );
    } catch (e, st) {
      debugPrint('[PlayerRecharge] 购买失败: $e\n$st');

      if (purchaseGeneration == _purchaseGeneration) {
        final failureKind = switch (state.paymentStage) {
          PlayerRechargePaymentStage.creatingOrder =>
            PlayerRechargePurchaseFailureKind.orderCreation,
          PlayerRechargePaymentStage.verifying =>
            PlayerRechargePurchaseFailureKind.verification,
          _ => PlayerRechargePurchaseFailureKind.payment,
        };
        state = state.copyWith(
          status: PlayerRechargeUnlockStatus.failed,
          purchaseFailureKind: failureKind,
          error: e,
        );
      }
    } finally {
      await sub?.cancel();
      await errorSub?.cancel();
      loading.hide();
    }
  }

  /// 使用金币直接解锁剧集
  Future<void> unlockWithCoin({
    required bool autoUnlockNext,
    required int coin,
    required int dramaId,
    required int episodeNo,
    required String shortTitle,
    required String cover,
    required int episodeId,
  }) async {
    final unlockGeneration = ++_purchaseGeneration;
    state = state.copyWith(status: PlayerRechargeUnlockStatus.processing);

    try {
      debugPrint(
        '[PlayerRecharge] 开始使用金币解锁剧集: dramaId=$dramaId, episodeNo=$episodeNo, coin=$coin',
      );

      final result = await ref
          .read(playerRechargeUnlockRepositoryProvider)
          .unlockEpisodeWithCoin(
            autoUnlockNext: autoUnlockNext,
            coin: coin,
            cover: cover,
            dramaId: dramaId,
            episodeId: episodeId,
            episodeNo: episodeNo,
            shortTitle: shortTitle,
          );

      if (unlockGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      if (result.success) {
        debugPrint('[PlayerRecharge] 金币解锁成功: ${result.toJson()}');

        // 1. 更新 entitlement 状态（已解锁剧集列表 + 金币余额）
        final episodeIdStr = result.episodeId.toString();
        ref
            .read(entitlementControllerProvider.notifier)
            .updateAfterCoinUnlock(
              episodeId: episodeIdStr,
              coinBalance: result.coin,
              bonusBalance: result.bonusCoin,
            );

        // 2. 更新 feed 中对应 episode 的播放地址（如果 API 返回了 sourceUrl）
        if (result.sourceUrl != null && result.sourceUrl!.isNotEmpty) {
          final success = ref
              .read(playerFeedControllerProvider(sessionKey).notifier)
              .updateEpisodeVideoUrl(
                dramaId: result.dramaId.toString(),
                episodeId: episodeIdStr,
                sourceUrl: result.sourceUrl!,
              );

          if (success) {
            debugPrint('[PlayerRecharge] 已更新剧集播放地址，准备播放');
          }
        } else {
          debugPrint('[PlayerRecharge] API 未返回 sourceUrl，需要重新加载剧集数据');
        }

        state = state.copyWith(status: PlayerRechargeUnlockStatus.success);
      } else {
        throw Exception('Unlock failed: success=false');
      }
    } catch (e, st) {
      debugPrint('[PlayerRecharge] 金币解锁失败: $e\n$st');

      if (unlockGeneration == _purchaseGeneration) {
        state = state.copyWith(
          status: PlayerRechargeUnlockStatus.failed,
          error: e,
        );
      }
    }
  }

  bool _isCurrent(int generation) => generation == _generation;

  void _markPurchaseCancelled() {
    state = state.copyWith(
      status: PlayerRechargeUnlockStatus.cancelled,
      clearSelection: true,
      clearPaymentStage: true,
      clearPurchaseFailure: true,
      clearError: true,
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

  bool _isGoogleOnly(PaymentMethodOptions options) =>
      options.options.length == 1 &&
      PayChannel.isGoogle(options.options.single.payChannel);

  int get _clientOsType => defaultTargetPlatform == TargetPlatform.iOS ? 1 : 2;
}
