import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reward_coins_repository_provider.dart';
import '../domain/reward_coins_check_in_status.dart';
import '../domain/reward_coins_check_in_claim_result.dart';
import '../../entitlement/application/entitlement_controller.dart';
import '../../pay/application/payment_loading_controller.dart';

class RewardCoinsState {
  const RewardCoinsState({
    this.checkInStatus,
    this.isLoading = false,
    this.error,
  });

  final RewardCoinsCheckInStatus? checkInStatus;
  final bool isLoading;
  final Object? error;

  RewardCoinsState copyWith({
    RewardCoinsCheckInStatus? checkInStatus,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return RewardCoinsState(
      checkInStatus: checkInStatus ?? this.checkInStatus,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final rewardCoinsControllerProvider =
    NotifierProvider<RewardCoinsController, RewardCoinsState>(
      RewardCoinsController.new,
    );

class RewardCoinsController extends Notifier<RewardCoinsState> {
  int _generation = 0;

  @override
  RewardCoinsState build() {
    return const RewardCoinsState();
  }

  Future<void> loadCheckInStatus() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final status = await ref
          .read(rewardCoinsRepositoryProvider)
          .getCheckInStatus();
      if (generation != _generation) return;
      state = state.copyWith(
        checkInStatus: status,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<RewardCoinsCheckInClaimResult?> claimCheckIn() async {
    if (state.isLoading) return null;

    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    state = state.copyWith(isLoading: true, clearError: true);
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
      if (state.isLoading) state = state.copyWith(isLoading: false);
    }
  }
}
