import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reward_coins_repository_provider.dart';
import '../domain/reward_coins_check_in_status.dart';
import '../domain/reward_coins_check_in_claim_result.dart';
import '../domain/reward_coin_remaining.dart';
import '../domain/reward_task.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/application/payment_loading_controller.dart';

class RewardCoinsState {
  const RewardCoinsState({
    this.checkInStatus,
    this.remainingCoin,
    this.tasks = const [],
    this.isCheckInLoading = false,
    this.isTasksLoading = false,
    this.isClaiming = false,
    this.checkInError,
    this.tasksError,
    this.error,
  });

  final RewardCoinsCheckInStatus? checkInStatus;

  /// null 表示接口尚未成功返回；个人中心此时不展示入口角标。
  final RewardCoinRemaining? remainingCoin;
  final List<RewardTask> tasks;
  final bool isCheckInLoading;
  final bool isTasksLoading;
  final bool isClaiming;
  final Object? checkInError;
  final Object? tasksError;
  final Object? error;

  RewardCoinsState copyWith({
    RewardCoinsCheckInStatus? checkInStatus,
    RewardCoinRemaining? remainingCoin,
    List<RewardTask>? tasks,
    bool? isCheckInLoading,
    bool? isTasksLoading,
    bool? isClaiming,
    Object? checkInError,
    Object? tasksError,
    Object? error,
    bool clearCheckInError = false,
    bool clearTasksError = false,
    bool clearError = false,
    bool clearRemainingCoin = false,
  }) {
    return RewardCoinsState(
      checkInStatus: checkInStatus ?? this.checkInStatus,
      remainingCoin: clearRemainingCoin
          ? null
          : remainingCoin ?? this.remainingCoin,
      tasks: tasks ?? this.tasks,
      isCheckInLoading: isCheckInLoading ?? this.isCheckInLoading,
      isTasksLoading: isTasksLoading ?? this.isTasksLoading,
      isClaiming: isClaiming ?? this.isClaiming,
      checkInError: clearCheckInError
          ? null
          : checkInError ?? this.checkInError,
      tasksError: clearTasksError ? null : tasksError ?? this.tasksError,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final rewardCoinsControllerProvider =
    NotifierProvider<RewardCoinsController, RewardCoinsState>(
      RewardCoinsController.new,
    );

class RewardCoinsController extends Notifier<RewardCoinsState> {
  int _checkInGeneration = 0;
  int _tasksGeneration = 0;
  int _remainingCoinGeneration = 0;

  @override
  RewardCoinsState build() {
    return const RewardCoinsState(isCheckInLoading: true, isTasksLoading: true);
  }

  Future<void> loadCheckInStatus() async {
    final generation = ++_checkInGeneration;
    final hasCurrentStatus = state.checkInStatus != null;
    // 已展示签到卡片时在后台静默刷新，避免每次进入页面都替换成 loading
    // 占位。只有初次加载才展示 loading 状态。
    if (!hasCurrentStatus) {
      state = state.copyWith(isCheckInLoading: true, clearCheckInError: true);
    }
    try {
      final status = await ref
          .read(rewardCoinsRepositoryProvider)
          .getCheckInStatus();
      if (generation != _checkInGeneration) return;
      if (hasCurrentStatus &&
          _isSameCheckInStatus(state.checkInStatus!, status)) {
        return;
      }
      state = state.copyWith(
        checkInStatus: status,
        isCheckInLoading: false,
        clearCheckInError: true,
      );
    } catch (error) {
      if (generation != _checkInGeneration) return;
      // 后台刷新失败时继续展示上一次成功的签到信息，不打断用户浏览。
      if (hasCurrentStatus) return;
      state = state.copyWith(isCheckInLoading: false, checkInError: error);
    }
  }

  Future<void> loadTasks() async {
    final generation = ++_tasksGeneration;
    state = state.copyWith(isTasksLoading: true, clearTasksError: true);
    try {
      final tasks = await ref
          .read(rewardCoinsRepositoryProvider)
          .getTasks(rewardType: 1);
      if (generation != _tasksGeneration) return;
      state = state.copyWith(
        tasks: tasks,
        isTasksLoading: false,
        clearTasksError: true,
      );
    } catch (error) {
      if (generation != _tasksGeneration) return;
      state = state.copyWith(isTasksLoading: false, tasksError: error);
    }
  }

  Future<void> loadRemainingCoin() async {
    final generation = ++_remainingCoinGeneration;
    try {
      final remainingCoin = await ref
          .read(rewardCoinsRepositoryProvider)
          .getRemainingCoin();
      if (generation != _remainingCoinGeneration) return;
      // 个人中心保留上次成功值；只有服务端数值变化时才重建标签，避免切回
      // Me 页面时标签闪烁或产生无意义的 UI 更新。
      if (state.remainingCoin?.value == remainingCoin.value) return;
      state = state.copyWith(remainingCoin: remainingCoin);
    } catch (_) {
      if (generation != _remainingCoinGeneration) return;
      // 按产品约定，接口失败或未取得数据时不展示标签。
      state = state.copyWith(clearRemainingCoin: true);
    }
  }

  Future<void> reportTaskAction({required String actionKey}) async {
    await ref
        .read(rewardCoinsRepositoryProvider)
        .reportTaskAction(actionKey: actionKey);
    await loadTasks();
  }

  Future<RewardCoinsCheckInClaimResult?> claimTask({
    required String taskKey,
  }) async {
    if (state.isClaiming) return null;

    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    state = state.copyWith(isClaiming: true, clearError: true);
    loading.show(label: PaymentLoadingLabel.loading);
    try {
      final result = await ref
          .read(rewardCoinsRepositoryProvider)
          .claimTask(taskKey: taskKey);
      if (result.isSuccess) {
        await Future.wait([
          loadTasks(),
          ref.read(entitlementControllerProvider.notifier).refreshFromServer(),
          loadRemainingCoin(),
        ]);
      }
      return result;
    } catch (error) {
      state = state.copyWith(error: error);
      rethrow;
    } finally {
      loading.hide();
      if (state.isClaiming) state = state.copyWith(isClaiming: false);
    }
  }

  Future<RewardCoinsCheckInClaimResult?> claimCheckIn() async {
    if (state.isClaiming) return null;

    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    state = state.copyWith(isClaiming: true, clearError: true);
    loading.show(label: PaymentLoadingLabel.loading);
    try {
      final result = await ref
          .read(rewardCoinsRepositoryProvider)
          .claimCheckIn();
      if (result.isSuccess) {
        await Future.wait([
          loadCheckInStatus(),
          ref.read(entitlementControllerProvider.notifier).refreshFromServer(),
          loadRemainingCoin(),
        ]);
      }
      return result;
    } catch (error) {
      state = state.copyWith(error: error);
      rethrow;
    } finally {
      loading.hide();
      if (state.isClaiming) state = state.copyWith(isClaiming: false);
    }
  }
}

bool _isSameCheckInStatus(
  RewardCoinsCheckInStatus current,
  RewardCoinsCheckInStatus next,
) {
  if (current.checkedDays != next.checkedDays ||
      current.checkedToday != next.checkedToday ||
      current.currentDay != next.currentDay ||
      current.days.length != next.days.length) {
    return false;
  }
  for (var index = 0; index < current.days.length; index++) {
    final currentDay = current.days[index];
    final nextDay = next.days[index];
    if (currentDay.checked != nextDay.checked ||
        currentDay.claimable != nextDay.claimable ||
        currentDay.current != nextDay.current ||
        currentDay.day != nextDay.day ||
        currentDay.rewardCoin != nextDay.rewardCoin) {
      return false;
    }
  }
  return true;
}
