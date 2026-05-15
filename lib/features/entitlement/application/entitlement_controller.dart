import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entitlement_repository_provider.dart';
import '../domain/entitlement_feature_config.dart';
import '../domain/episode_access_decision.dart';
import '../domain/episode_unlock_type.dart';
import '../domain/user_entitlement_state.dart';

/// Entitlement 功能开关 provider。
///
/// 当前返回本地默认配置，未来可以替换为 remote config 或服务端策略，但默认关闭的未来
/// 能力不能在 UI 层自行打开。
final entitlementFeatureConfigProvider = Provider<EntitlementFeatureConfig>((
  ref,
) {
  return const EntitlementFeatureConfig();
});

/// Entitlement 的唯一应用层状态入口。
///
/// Player、Store、Membership、Wallet 后续都应该通过这里读取权益状态或发起 mock
/// 权益动作，避免每个 feature 各自维护余额/会员/已解锁集合造成状态不一致。
final entitlementControllerProvider =
    NotifierProvider<EntitlementController, UserEntitlementState>(
      EntitlementController.new,
    );

/// 权益控制器。
///
/// 这里负责“能不能播”和“mock 权益动作”的状态机，但不管理 media session、不打开
/// 路由、不展示弹窗。这样播放器可以保持唯一播放状态来源，entitlement 只提供业务决策。
class EntitlementController extends Notifier<UserEntitlementState> {
  @override
  UserEntitlementState build() => const UserEntitlementState.guest();

  Future<void> load() async {
    state = await ref.read(entitlementRepositoryProvider).fetchState();
  }

  /// 判定某集当前应该播放、跳会员、弹金币确认、弹充值，还是等待。
  ///
  /// 这个方法允许写入 pendingUnlock，因为 UI 关闭弹窗或从充值/会员页返回时，需要回到
  /// 同一个目标继续判断。它不会执行扣金币，避免“判定”阶段产生副作用。
  EpisodeAccessDecision evaluateAccess({
    required String dramaId,
    required String episodeId,
    required String itemId,
    required EpisodeUnlockType unlockType,
    int price = 0,
    bool isUnavailable = false,
  }) {
    final decision = _evaluate(
      dramaId: dramaId,
      episodeId: episodeId,
      itemId: itemId,
      unlockType: unlockType,
      price: price,
      isUnavailable: isUnavailable,
    );

    if (decision.type == EpisodeAccessDecisionType.allowPlay) {
      state = state.copyWith(
        clearPendingUnlock: true,
        clearLastUnlockError: true,
      );
      return decision;
    }

    state = state.copyWith(
      pendingUnlock: PendingEpisodeUnlock(
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
        operationId: decision.operationId,
        reason: decision.reason,
      ),
    );
    return decision;
  }

  Future<void> setAutoUnlockEnabled(bool enabled) async {
    state = await ref
        .read(entitlementRepositoryProvider)
        .setAutoUnlockEnabled(enabled);
  }

  /// 用金币解锁单集。
  ///
  /// mock 阶段会直接扣本地余额；真实阶段这里应调用服务端扣费/权益接口，成功后再刷新
  /// UserEntitlementState。相同 operationId 必须幂等，避免重试导致重复扣费。
  Future<EpisodeAccessDecision> unlockWithCoins({
    required String dramaId,
    required String episodeId,
    required String itemId,
    required int price,
    required String operationId,
  }) async {
    state = state.copyWith(
      inFlightUnlockEpisodeId: episodeId,
      clearLastUnlockError: true,
    );

    try {
      state = await ref
          .read(entitlementRepositoryProvider)
          .unlockEpisodeWithCoins(
            dramaId: dramaId,
            episodeId: episodeId,
            price: price,
            operationId: operationId,
          );
      state = state.copyWith(
        clearPendingUnlock: true,
        clearInFlightUnlock: true,
        clearLastUnlockError: true,
      );
      return EpisodeAccessDecision(
        type: EpisodeAccessDecisionType.allowPlay,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: EpisodeUnlockType.coins,
        price: price,
        balance: state.coinBalance,
        operationId: operationId,
      );
    } catch (error) {
      state = state.copyWith(clearInFlightUnlock: true, lastUnlockError: error);
      return EpisodeAccessDecision(
        type: EpisodeAccessDecisionType.waitUnlock,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: EpisodeUnlockType.coins,
        price: price,
        balance: state.coinBalance,
        reason: 'coin_deduction_failed',
        operationId: operationId,
      );
    }
  }

  Future<void> grantMockMembership({required String source}) async {
    state = await ref
        .read(entitlementRepositoryProvider)
        .grantMockMembership(source: source);
  }

  Future<void> grantMockCoins({
    required int amount,
    required String source,
  }) async {
    state = await ref
        .read(entitlementRepositoryProvider)
        .grantMockCoins(amount: amount, source: source);
  }

  void clearPendingUnlock() {
    state = state.copyWith(clearPendingUnlock: true);
  }

  EpisodeAccessDecision _evaluate({
    required String dramaId,
    required String episodeId,
    required String itemId,
    required EpisodeUnlockType unlockType,
    required int price,
    required bool isUnavailable,
  }) {
    if (isUnavailable) {
      return _decision(
        type: EpisodeAccessDecisionType.waitUnlock,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
        reason: 'episode_unavailable',
      );
    }

    if (unlockType == EpisodeUnlockType.free) {
      return _decision(
        type: EpisodeAccessDecisionType.allowPlay,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
      );
    }

    // 会员是全局放行权益：只要内容可用，会员剧集和金币剧集都可以直接播。
    // 这条规则必须放在金币余额/自动解锁之前，避免会员账号被误扣金币或弹充值。
    if (state.isMember) {
      return _decision(
        type: EpisodeAccessDecisionType.allowPlay,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
      );
    }

    if (unlockType == EpisodeUnlockType.membership) {
      return _decision(
        type: EpisodeAccessDecisionType.goMembership,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
        reason: 'membership_required',
      );
    }

    final config = ref.read(entitlementFeatureConfigProvider);
    if (!config.enableCoinUnlock) {
      return _decision(
        type: EpisodeAccessDecisionType.waitUnlock,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
        reason: 'coin_unlock_disabled',
      );
    }

    if (state.isEpisodeUnlocked(episodeId)) {
      return _decision(
        type: EpisodeAccessDecisionType.allowPlay,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
      );
    }

    if (state.coinBalance < price) {
      return _decision(
        type: EpisodeAccessDecisionType.showRechargeDialog,
        dramaId: dramaId,
        episodeId: episodeId,
        itemId: itemId,
        unlockType: unlockType,
        price: price,
        reason: 'insufficient_coins',
      );
    }

    return _decision(
      type: EpisodeAccessDecisionType.showCoinUnlockDialog,
      dramaId: dramaId,
      episodeId: episodeId,
      itemId: itemId,
      unlockType: unlockType,
      price: price,
      reason: state.autoUnlockEnabled
          ? 'auto_unlock_requires_current_confirmation'
          : 'auto_unlock_disabled',
      operationId: _operationIdFor(dramaId, episodeId),
    );
  }

  EpisodeAccessDecision _decision({
    required EpisodeAccessDecisionType type,
    required String dramaId,
    required String episodeId,
    required String itemId,
    required EpisodeUnlockType unlockType,
    int? price,
    String? reason,
    String? operationId,
  }) {
    return EpisodeAccessDecision(
      type: type,
      dramaId: dramaId,
      episodeId: episodeId,
      itemId: itemId,
      unlockType: unlockType,
      price: price,
      balance: state.coinBalance,
      reason: reason,
      operationId: operationId,
    );
  }

  String _operationIdFor(String dramaId, String episodeId) {
    return 'coin-unlock:$dramaId:$episodeId';
  }
}
