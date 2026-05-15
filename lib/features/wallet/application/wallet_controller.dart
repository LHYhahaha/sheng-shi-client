import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_repository_provider.dart';
import '../domain/wallet_record.dart';

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

  final bool isLoading;
  final int coins;
  final int bonus;
  final bool autoUnlockNextEpisode;
  final bool autoUnlockTouched;
  final WalletConsumptionStatus consumptionFilter;
  final List<WalletRecord> transactionRecords;
  final List<WalletRecord> consumptionRecords;
  final List<WalletRecord> coinRecords;
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
/// 当前实现是 mock 本地状态，但边界按真实钱包设计：余额和流水只来自 repository，
/// UI 操作只能改本地偏好或 mock 奖励领取状态，不能直接制造消费/充值结果。
class WalletController extends Notifier<WalletState> {
  int _generation = 0;

  @override
  WalletState build() => const WalletState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = await ref.read(walletRepositoryProvider).fetchWallet();
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        coins: data.coins,
        bonus: data.bonus,
        // 用户本地切过自动解锁后，load 不覆盖这个开关，避免刷新接口把刚操作的 UI
        // 打回旧值。接真实接口时应在保存成功后再清理 touched 或以服务端返回为准。
        autoUnlockNextEpisode: state.autoUnlockTouched
            ? state.autoUnlockNextEpisode
            : data.autoUnlockNextEpisode,
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

  void setAutoUnlockNextEpisode(bool value) {
    state = state.copyWith(
      autoUnlockNextEpisode: value,
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
