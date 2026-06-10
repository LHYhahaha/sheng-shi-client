import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/provider/iap_purchase_service_provider.dart';
import '../../pay/provider/pay_repository_provider.dart';
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

/// 播放器内 entitlement 充值解锁状态。
///
/// 这不是播放器真实播放状态，也不是 Store 订单状态。它只管理 locked episode 金币不足
/// 时的弹窗展示和 mock purchase 流程，成功后再通知 PlayerPage 继续 pending unlock。
class PlayerRechargeUnlockState {
  const PlayerRechargeUnlockState({
    required this.status,
    this.itemId,
    this.offer,
    this.selectedCoinPackageId,
    this.selectedMembershipPackageId,
    this.error,
  });

  const PlayerRechargeUnlockState.initial()
    : status = PlayerRechargeUnlockStatus.idle,
      itemId = null,
      offer = null,
      selectedCoinPackageId = null,
      selectedMembershipPackageId = null,
      error = null;

  final PlayerRechargeUnlockStatus status;
  final String? itemId;
  final PlayerRechargeUnlockOffer? offer;
  final String? selectedCoinPackageId;
  final String? selectedMembershipPackageId;
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
    Object? error,
    bool clearSelection = false,
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
    state = PlayerRechargeUnlockState(
      status: PlayerRechargeUnlockStatus.loading,
      itemId: itemId,
      offer: null,
      selectedCoinPackageId: null,
      selectedMembershipPackageId: null,
    );

    try {
      final offer = await ref
          .read(playerRechargeUnlockRepositoryProvider)
          .fetchOffer(itemId: itemId, requiredCoins: requiredCoins);
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
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        status: PlayerRechargeUnlockStatus.failed,
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
      clearError: true,
    );
    return _startMockPurchase();
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
      clearError: true,
    );
    return _startMockPurchase();
  }

  void close() {
    _purchaseGeneration++;
    state = state.copyWith(
      status: PlayerRechargeUnlockStatus.cancelled,
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

  Future<void> _startMockPurchase() async {
    final purchaseGeneration = ++_purchaseGeneration;
    state = state.copyWith(status: PlayerRechargeUnlockStatus.processing);

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
      final productType = isCoinPackage ? 1 : 2; // 1=金币商品, 2=会员商品

      if (productId == 0) {
        throw Exception('Invalid productId: $packageId');
      }

      // 3. 创建订单
      debugPrint('[PlayerRecharge] 开始创建订单: productId=$productId');

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
      final iapService = ref.read(iapPurchaseServiceProvider);
      if (iapService == null) {
        throw Exception('IAP purchase service not available');
      }

      // 5. 从 iapInfo 中获取商品详情和 offerToken（无需重复查询 IAP）
      final iapInfo = isCoinPackage
          ? selectedCoinPackage.iapInfo
          : selectedMembershipPackage!.iapInfo;

      final productDetails = iapInfo?.productDetails;
      if (productDetails == null) {
        throw Exception('IAP product details not found in iapInfo');
      }

      if (purchaseGeneration != _purchaseGeneration ||
          state.status != PlayerRechargeUnlockStatus.processing) {
        return;
      }

      // 6. 设置 Completer 等待购买结果
      final completer = Completer<PurchaseDetails?>();
      StreamSubscription? sub;

      sub = iapService.purchaseStream.listen((details) {
        if (details.productID == productDetails.id) {
          completer.complete(details);
          sub?.cancel();
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

      await iapService.buyProduct(
        product: productDetails,
        isConsumable: isConsumable,
        offerToken: offerToken,
      );

      // 8. 等待购买结果（设置超时）
      final purchaseDetails = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('[PlayerRecharge] 购买超时');
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
        throw Exception('Purchase timeout or cancelled');
      }

      if (purchaseDetails.status == PurchaseStatus.purchased) {
        // 直接完成购买（跳过验单）
        debugPrint('[PlayerRecharge] 购买成功，直接完成（跳过验单）');
        await iapService.completePurchase(purchaseDetails);

        if (purchaseGeneration != _purchaseGeneration ||
            state.status != PlayerRechargeUnlockStatus.processing) {
          return;
        }

        // 标记成功
        state = state.copyWith(status: PlayerRechargeUnlockStatus.success);
        debugPrint('[PlayerRecharge] 购买流程完成（跳过验单和权益刷新）');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        throw Exception('Purchase failed: ${purchaseDetails.error}');
      }
    } catch (e, st) {
      debugPrint('[PlayerRecharge] 购买失败: $e\n$st');

      if (purchaseGeneration == _purchaseGeneration) {
        state = state.copyWith(
          status: PlayerRechargeUnlockStatus.failed,
          error: e,
        );
      }
    }
  }

  /// 使用金币直接解锁剧集
  Future<void> unlockWithCoin({
    required bool autoUnlockNext,
    required int coin,
    required int dramaId,
    required int episodeNo,
    required String shortTitle,
    String? cover,
    int? episodeId,
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
}
