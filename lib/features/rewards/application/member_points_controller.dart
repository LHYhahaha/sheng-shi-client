import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/member_points_repository_provider.dart';
import '../domain/member_point_claim_result.dart';
import '../domain/member_point_daily_detail.dart';
import '../domain/member_point_exchange_options.dart';
import '../domain/member_point_exchange_result.dart';
import '../../pay/application/payment_loading_controller.dart';
import '../../entitlement/application/entitlement_controller.dart';

class MemberPointsState {
  const MemberPointsState({
    this.data,
    this.exchangeOptions,
    this.isLoading = false,
    this.isClaiming = false,
    this.isExchanging = false,
    this.error,
  });

  final MemberPointDailyDetail? data;
  final MemberPointExchangeOptions? exchangeOptions;
  final bool isLoading;
  final bool isClaiming;
  final bool isExchanging;
  final Object? error;

  MemberPointsState copyWith({
    MemberPointDailyDetail? data,
    MemberPointExchangeOptions? exchangeOptions,
    bool? isLoading,
    bool? isClaiming,
    bool? isExchanging,
    Object? error,
    bool clearError = false,
  }) {
    return MemberPointsState(
      data: data ?? this.data,
      exchangeOptions: exchangeOptions ?? this.exchangeOptions,
      isLoading: isLoading ?? this.isLoading,
      isClaiming: isClaiming ?? this.isClaiming,
      isExchanging: isExchanging ?? this.isExchanging,
      error: clearError ? null : error ?? this.error,
    );
  }
}

final memberPointsControllerProvider =
    NotifierProvider<MemberPointsController, MemberPointsState>(
      MemberPointsController.new,
    );

class MemberPointsController extends Notifier<MemberPointsState> {
  int _generation = 0;

  @override
  MemberPointsState build() {
    return const MemberPointsState();
  }

  Future<void> loadDailyDetail() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(memberPointsRepositoryProvider);
      final (data, exchangeOptions) = await (
        repository.getDailyDetail(),
        repository.getExchangeOptions(),
      ).wait;
      if (generation != _generation) return;
      state = state.copyWith(
        data: data,
        exchangeOptions: exchangeOptions,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<MemberPointClaimResult?> claimReward({required String taskKey}) async {
    if (state.isClaiming || state.isExchanging) return null;

    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    state = state.copyWith(isClaiming: true, clearError: true);
    loading.show(label: PaymentLoadingLabel.loading);
    try {
      final result = await ref
          .read(memberPointsRepositoryProvider)
          .claimReward(taskKey: taskKey);

      if (result.isSuccess) {
        await _refreshMemberPointsAndEntitlements();
      }

      return result;
    } catch (error) {
      state = state.copyWith(error: error);
      rethrow;
    } finally {
      loading.hide();
      state = state.copyWith(isClaiming: false);
    }
  }

  Future<MemberPointExchangeResult?> exchange({required int tierId}) async {
    if (state.isClaiming || state.isExchanging) return null;

    final loading = ref.read(paymentLoadingControllerProvider.notifier);
    state = state.copyWith(isExchanging: true, clearError: true);
    loading.show(label: PaymentLoadingLabel.loading);
    try {
      final result = await ref
          .read(memberPointsRepositoryProvider)
          .exchange(tierId: tierId);

      if (result.isSuccess) {
        await _refreshMemberPointsAndEntitlements();
      }

      return result;
    } catch (error) {
      state = state.copyWith(error: error);
      rethrow;
    } finally {
      loading.hide();
      state = state.copyWith(isExchanging: false);
    }
  }

  Future<void> _refreshMemberPointsAndEntitlements() async {
    await (
      loadDailyDetail(),
      ref.read(entitlementControllerProvider.notifier).refreshFromServer(),
    ).wait;
  }
}
