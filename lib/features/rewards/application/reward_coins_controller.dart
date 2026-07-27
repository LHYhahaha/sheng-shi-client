import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reward_coins_repository_provider.dart';
import '../domain/reward_coins_check_in_status.dart';
import '../domain/reward_coins_check_in_claim_result.dart';
import '../domain/reward_task.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/application/payment_loading_controller.dart';

class RewardCoinsState {
  const RewardCoinsState({
    this.checkInStatus,
    this.tasks = const [],
    this.isCheckInLoading = false,
    this.isTasksLoading = false,
    this.isClaiming = false,
    this.checkInError,
    this.tasksError,
    this.error,
  });

  final RewardCoinsCheckInStatus? checkInStatus;
  final List<RewardTask> tasks;
  final bool isCheckInLoading;
  final bool isTasksLoading;
  final bool isClaiming;
  final Object? checkInError;
  final Object? tasksError;
  final Object? error;

  RewardCoinsState copyWith({
    RewardCoinsCheckInStatus? checkInStatus,
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
  }) {
    return RewardCoinsState(
      checkInStatus: checkInStatus ?? this.checkInStatus,
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

  @override
  RewardCoinsState build() {
    return const RewardCoinsState(isCheckInLoading: true, isTasksLoading: true);
  }

  Future<void> loadCheckInStatus() async {
    final generation = ++_checkInGeneration;
    state = state.copyWith(isCheckInLoading: true, clearCheckInError: true);
    try {
      final status = await ref
          .read(rewardCoinsRepositoryProvider)
          .getCheckInStatus();
      if (generation != _checkInGeneration) return;
      state = state.copyWith(
        checkInStatus: status,
        isCheckInLoading: false,
        clearCheckInError: true,
      );
    } catch (error) {
      if (generation != _checkInGeneration) return;
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
