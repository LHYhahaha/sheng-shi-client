import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_repository_provider.dart';
import '../domain/store_package.dart';

final storeControllerProvider = NotifierProvider<StoreController, StoreState>(
  StoreController.new,
);

class StoreState {
  const StoreState({
    required this.isLoading,
    required this.balance,
    required this.coinPackages,
    required this.vipPackages,
    required this.tips,
    required this.selectedPackageId,
    required this.confirmationPackageId,
    this.error,
  });

  const StoreState.initial()
    : isLoading = true,
      balance = 0,
      coinPackages = const [],
      vipPackages = const [],
      tips = null,
      selectedPackageId = null,
      confirmationPackageId = null,
      error = null;

  final bool isLoading;
  final int balance;
  final List<StorePackage> coinPackages;
  final List<StorePackage> vipPackages;
  final StoreTips? tips;
  final String? selectedPackageId;
  final String? confirmationPackageId;
  final Object? error;

  List<StorePackage> get packages => [...coinPackages, ...vipPackages];

  StorePackage? get selectedPackage => packageById(selectedPackageId);

  StorePackage? get confirmationPackage => packageById(confirmationPackageId);

  bool get hasContent => !isLoading && error == null;

  StorePackage? packageById(String? id) {
    if (id == null) {
      return null;
    }

    for (final package in packages) {
      if (package.id == id) {
        return package;
      }
    }
    return null;
  }

  StoreState copyWith({
    bool? isLoading,
    int? balance,
    List<StorePackage>? coinPackages,
    List<StorePackage>? vipPackages,
    StoreTips? tips,
    String? selectedPackageId,
    String? confirmationPackageId,
    Object? error,
    bool clearError = false,
    bool clearConfirmation = false,
  }) {
    return StoreState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      coinPackages: coinPackages ?? this.coinPackages,
      vipPackages: vipPackages ?? this.vipPackages,
      tips: tips ?? this.tips,
      selectedPackageId: selectedPackageId ?? this.selectedPackageId,
      confirmationPackageId: clearConfirmation
          ? null
          : confirmationPackageId ?? this.confirmationPackageId,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class StoreController extends Notifier<StoreState> {
  int _generation = 0;

  @override
  StoreState build() => const StoreState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearConfirmation: true,
    );

    try {
      final data = await ref.read(storeRepositoryProvider).fetchRechargeData();
      if (!_isCurrent(generation)) {
        return;
      }

      final selectedId = data.coinPackages.isNotEmpty
          ? data.coinPackages.first.id
          : data.vipPackages.isNotEmpty
          ? data.vipPackages.first.id
          : null;
      state = state.copyWith(
        isLoading: false,
        balance: data.balance,
        coinPackages: List<StorePackage>.unmodifiable(data.coinPackages),
        vipPackages: List<StorePackage>.unmodifiable(data.vipPackages),
        tips: data.tips,
        selectedPackageId: selectedId,
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

  void selectPackage(String id) {
    if (state.packageById(id) == null) {
      return;
    }

    state = state.copyWith(selectedPackageId: id);
  }

  void showConfirmation() {
    final selectedPackage = state.selectedPackage;
    if (selectedPackage == null) {
      return;
    }

    state = state.copyWith(confirmationPackageId: selectedPackage.id);
  }

  void hideConfirmation() {
    state = state.copyWith(clearConfirmation: true);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
