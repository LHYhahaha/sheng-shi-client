import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/membership_repository_provider.dart';
import '../domain/membership_plan.dart';

final membershipControllerProvider =
    NotifierProvider<MembershipController, MembershipState>(
      MembershipController.new,
    );

enum MembershipPurchaseStatus { idle, processing, success, cancelled }

class MembershipState {
  const MembershipState({
    required this.isLoading,
    required this.isActive,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.plans,
    required this.benefits,
    required this.tips,
    required this.selectedPlanId,
    required this.confirmationPlanId,
    required this.purchaseStatus,
    this.error,
  });

  const MembershipState.initial()
    : isLoading = true,
      isActive = false,
      heroTitle = '',
      heroSubtitle = '',
      plans = const [],
      benefits = const [],
      tips = null,
      selectedPlanId = null,
      confirmationPlanId = null,
      purchaseStatus = MembershipPurchaseStatus.idle,
      error = null;

  final bool isLoading;
  final bool isActive;
  final String heroTitle;
  final String heroSubtitle;
  final List<MembershipPlan> plans;
  final List<MembershipBenefit> benefits;
  final MembershipTips? tips;
  final String? selectedPlanId;
  final String? confirmationPlanId;
  final MembershipPurchaseStatus purchaseStatus;
  final Object? error;

  bool get hasContent => !isLoading && error == null;

  MembershipPlan? get selectedPlan => planById(selectedPlanId);

  MembershipPlan? get confirmationPlan => planById(confirmationPlanId);

  MembershipPlan? planById(String? id) {
    if (id == null) {
      return null;
    }

    for (final plan in plans) {
      if (plan.id == id) {
        return plan;
      }
    }
    return null;
  }

  MembershipState copyWith({
    bool? isLoading,
    bool? isActive,
    String? heroTitle,
    String? heroSubtitle,
    List<MembershipPlan>? plans,
    List<MembershipBenefit>? benefits,
    MembershipTips? tips,
    String? selectedPlanId,
    String? confirmationPlanId,
    MembershipPurchaseStatus? purchaseStatus,
    Object? error,
    bool clearError = false,
    bool clearConfirmation = false,
  }) {
    return MembershipState(
      isLoading: isLoading ?? this.isLoading,
      isActive: isActive ?? this.isActive,
      heroTitle: heroTitle ?? this.heroTitle,
      heroSubtitle: heroSubtitle ?? this.heroSubtitle,
      plans: plans ?? this.plans,
      benefits: benefits ?? this.benefits,
      tips: tips ?? this.tips,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      confirmationPlanId: clearConfirmation
          ? null
          : confirmationPlanId ?? this.confirmationPlanId,
      purchaseStatus: purchaseStatus ?? this.purchaseStatus,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class MembershipController extends Notifier<MembershipState> {
  int _generation = 0;
  int _purchaseGeneration = 0;

  @override
  MembershipState build() => const MembershipState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearConfirmation: true,
    );

    try {
      final data = await ref
          .read(membershipRepositoryProvider)
          .fetchMembership();
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isActive: data.isActive,
        heroTitle: data.heroTitle,
        heroSubtitle: data.heroSubtitle,
        plans: List<MembershipPlan>.unmodifiable(data.plans),
        benefits: List<MembershipBenefit>.unmodifiable(data.benefits),
        tips: data.tips,
        selectedPlanId: data.plans.isEmpty ? null : data.plans.first.id,
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

  void selectPlan(String id) {
    if (state.planById(id) == null) {
      return;
    }

    state = state.copyWith(selectedPlanId: id);
  }

  void showConfirmation() {
    final selectedPlan = state.selectedPlan;
    if (selectedPlan == null) {
      return;
    }

    _purchaseGeneration++;
    state = state.copyWith(
      confirmationPlanId: selectedPlan.id,
      purchaseStatus: MembershipPurchaseStatus.idle,
    );
  }

  void hideConfirmation() {
    _purchaseGeneration++;
    state = state.copyWith(
      purchaseStatus: MembershipPurchaseStatus.idle,
      clearConfirmation: true,
    );
  }

  Future<void> confirmMockPurchase() async {
    if (state.confirmationPlan == null ||
        state.purchaseStatus != MembershipPurchaseStatus.idle) {
      return;
    }

    final purchaseGeneration = _purchaseGeneration;
    final planId = state.confirmationPlanId;
    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.processing);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (purchaseGeneration != _purchaseGeneration ||
        state.confirmationPlanId != planId ||
        state.purchaseStatus != MembershipPurchaseStatus.processing) {
      return;
    }

    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.success);
  }

  void cancelMockPurchase() {
    if (state.purchaseStatus != MembershipPurchaseStatus.idle) {
      return;
    }

    state = state.copyWith(purchaseStatus: MembershipPurchaseStatus.cancelled);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
