import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_repository_provider.dart';
import '../domain/wallet_record.dart';

final walletControllerProvider =
    NotifierProvider<WalletController, WalletState>(WalletController.new);

class WalletState {
  const WalletState({
    required this.isLoading,
    required this.coins,
    required this.bonus,
    required this.autoUnlockNextEpisode,
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
      transactionRecords = const [],
      consumptionRecords = const [],
      coinRecords = const [],
      error = null;

  final bool isLoading;
  final int coins;
  final int bonus;
  final bool autoUnlockNextEpisode;
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
      transactionRecords: transactionRecords ?? this.transactionRecords,
      consumptionRecords: consumptionRecords ?? this.consumptionRecords,
      coinRecords: coinRecords ?? this.coinRecords,
      error: clearError ? null : error ?? this.error,
    );
  }
}

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
        autoUnlockNextEpisode: data.autoUnlockNextEpisode,
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
    state = state.copyWith(autoUnlockNextEpisode: value);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
