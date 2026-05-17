import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/player_recharge_unlock_repository_provider.dart';
import '../domain/player_recharge_unlock_offer.dart';

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
/// 控制器只处理“金币不足且非会员时展示充值/会员组合弹窗”的 mock 流程，不触碰
/// media session，也不发放真实金币/会员。真实支付接入时，processing 后必须等待
/// 服务端验单和 entitlement 刷新，再由调用方决定是否继续播放 locked episode。
class PlayerRechargeUnlockController
    extends Notifier<PlayerRechargeUnlockState> {
  PlayerRechargeUnlockController(this.sessionKey);

  final String sessionKey;
  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  PlayerRechargeUnlockState build() =>
      const PlayerRechargeUnlockState.initial();

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
    state = const PlayerRechargeUnlockState.initial();
  }

  Future<void> _startMockPurchase() async {
    final purchaseGeneration = ++_purchaseGeneration;
    state = state.copyWith(status: PlayerRechargeUnlockStatus.processing);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (purchaseGeneration != _purchaseGeneration ||
        state.status != PlayerRechargeUnlockStatus.processing) {
      return;
    }
    state = state.copyWith(status: PlayerRechargeUnlockStatus.success);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
