import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entitlement/application/entitlement_controller.dart';
import '../data/wallet_repository_provider.dart';
import '../domain/wallet_record.dart';

/// Wallet feature 的唯一状态入口。
///
/// 钱包余额、自动解锁偏好和三类流水都从这里暴露。真实支付/权益接入后，余额和流水
/// 只能由 repository 刷新，UI 层不能因为某个 mock 购买成功就直接改钱包数值。
final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);

/// 钱包页状态，区分余额、赠币、消费记录、交易记录和金币任务记录。
///
/// 三类流水不要在客户端合并成一个“万能记录”列表：充值/消费/奖励在真实接口里
/// 对账口径不同，筛选、展示文案和跳转也会不同。这里保留分组边界，避免后续接
/// 支付与会员时把财务流水混在一起。
class WalletState {
  const WalletState({
    required this.isLoading,
    required this.coins,
    required this.bonus,
    required this.autoUnlockNextEpisode,
    required this.autoUnlockTouched,
    required this.consumptionFilter,
    required this.transactionRecords,
    required this.consumptionRecords,
    required this.coinRecords,
    this.error,
  });

  const WalletState.initial()
    : isLoading = true,
      coins = 0,
      bonus = 0,
      autoUnlockNextEpisode = false,
      autoUnlockTouched = false,
      consumptionFilter = WalletConsumptionStatus.spent,
      transactionRecords = const [],
      consumptionRecords = const [],
      coinRecords = const [],
      error = null;

  /// 钱包页是否正在加载余额和流水。
  ///
  /// 只覆盖钱包数据拉取，不表示领奖或自动解锁开关保存中。后续如果这些动作接接口，
  /// 应单独增加动作级状态，避免整页闪 loading。
  final bool isLoading;

  /// 可消费金币余额。
  ///
  /// 余额只能来自钱包数据刷新；充值、消费、奖励的客户端操作不应直接改这个字段，
  /// 否则会和服务端对账结果不一致。
  final int coins;

  /// 赠币余额。
  ///
  /// 赠币和金币可能有不同过期/消费规则，所以单独展示和保存，不合并到 coins。
  final int bonus;

  /// 是否自动解锁下一集。
  ///
  /// 这是用户偏好开关，不代表当前剧集一定可解锁。真正解锁仍要经过余额、会员权益
  /// 和 episode 状态判断。
  final bool autoUnlockNextEpisode;

  /// 用户本地是否已经操作过自动解锁开关。
  ///
  /// 用来避免 reload 用 mock/旧服务端值覆盖刚刚的本地选择。真实保存接口接入后，
  /// 可以在保存成功并刷新服务端状态后重置这个标记。
  final bool autoUnlockTouched;

  /// 消费记录页当前筛选状态。
  ///
  /// 只影响本地展示 spent/expired，不改变原始 `consumptionRecords`。不要把筛选后的
  /// 结果写回 records，否则切换筛选会丢数据。
  final WalletConsumptionStatus consumptionFilter;

  /// 充值/交易流水。
  ///
  /// 代表资金进入或订单交易记录，和内容消费流水不是同一口径，后续对账/发票入口也
  /// 应挂在这里而不是消费记录里。
  final List<WalletRecord> transactionRecords;

  /// 内容消费流水。
  ///
  /// 代表解锁、扣费、过期等消费侧记录。它可以按 spent/expired 筛选，但不应与充值
  /// 交易记录混排。
  final List<WalletRecord> consumptionRecords;

  /// 金币任务/奖励记录。
  ///
  /// 代表签到、奖励领取等活动记录。mock 领取只改记录状态，不直接改余额。
  final List<WalletRecord> coinRecords;

  /// 钱包数据加载错误。
  ///
  /// 只用于整页 retry。后续动作级错误应单独建字段，避免领奖失败导致钱包页整体失败。
  final Object? error;

  bool get hasContent => !isLoading && error == null;

  List<WalletRecord> recordsFor(WalletRecordType type) {
    return switch (type) {
      WalletRecordType.transaction => transactionRecords,
      WalletRecordType.consumption => consumptionRecords,
      WalletRecordType.coins => coinRecords,
    };
  }

  WalletState copyWith({
    bool? isLoading,
    int? coins,
    int? bonus,
    bool? autoUnlockNextEpisode,
    bool? autoUnlockTouched,
    WalletConsumptionStatus? consumptionFilter,
    List<WalletRecord>? transactionRecords,
    List<WalletRecord>? consumptionRecords,
    List<WalletRecord>? coinRecords,
    Object? error,
    bool clearError = false,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      coins: coins ?? this.coins,
      bonus: bonus ?? this.bonus,
      autoUnlockNextEpisode:
          autoUnlockNextEpisode ?? this.autoUnlockNextEpisode,
      autoUnlockTouched: autoUnlockTouched ?? this.autoUnlockTouched,
      consumptionFilter: consumptionFilter ?? this.consumptionFilter,
      transactionRecords: transactionRecords ?? this.transactionRecords,
      consumptionRecords: consumptionRecords ?? this.consumptionRecords,
      coinRecords: coinRecords ?? this.coinRecords,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// 钱包控制器。
///
/// 当前实现是 mock 本地状态，但 E3 起金币余额和自动解锁偏好以共享 EntitlementState
/// 为准。钱包 repository 仍负责流水、赠币和页面展示数据；自动解锁写入必须走
/// EntitlementController，避免 Player 的解锁决策和 Wallet 开关出现两套状态。
class WalletController extends Notifier<WalletState> {
  int _generation = 0;

  @override
  WalletState build() => const WalletState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = await ref.read(walletRepositoryProvider).fetchWallet();
      await ref.read(entitlementControllerProvider.notifier).load();
      if (!_isCurrent(generation)) {
        return;
      }

      final entitlementState = ref.read(entitlementControllerProvider);
      state = state.copyWith(
        isLoading: false,
        coins: entitlementState.coinBalance,
        bonus: data.bonus,
        // 自动解锁现在以 EntitlementState 为准，Player evaluateAccess 会读取同一份状态。
        // 钱包 mock 返回值只保留为历史接口占位，不再覆盖用户实际权益偏好。
        autoUnlockNextEpisode: entitlementState.autoUnlockEnabled,
        transactionRecords: List<WalletRecord>.unmodifiable(
          data.transactionRecords,
        ),
        consumptionRecords: List<WalletRecord>.unmodifiable(
          data.consumptionRecords,
        ),
        coinRecords: List<WalletRecord>.unmodifiable(data.coinRecords),
        clearError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> retry() => load();

  Future<void> setAutoUnlockNextEpisode(bool value) async {
    await ref
        .read(entitlementControllerProvider.notifier)
        .setAutoUnlockEnabled(value);
    final entitlementState = ref.read(entitlementControllerProvider);
    state = state.copyWith(
      autoUnlockNextEpisode: entitlementState.autoUnlockEnabled,
      autoUnlockTouched: true,
    );
  }

  void setConsumptionFilter(WalletConsumptionStatus value) {
    state = state.copyWith(consumptionFilter: value);
  }

  void claimReward(String id) {
    // mock 领取只改变金币任务记录的可领取态，不直接增加余额。真实奖励需要服务端
    // 发放和钱包刷新，否则客户端重复点击或重放状态会造成余额不可信。
    state = state.copyWith(
      coinRecords: List<WalletRecord>.unmodifiable(
        state.coinRecords.map((record) {
          if (record.id != id || !record.rewardEnabled) {
            return record;
          }
          return record.copyWith(rewardEnabled: false, rewardClaimed: true);
        }),
      ),
    );
  }

  bool _isCurrent(int generation) => generation == _generation;
}
