import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/wallet/application/wallet_controller.dart';
import 'package:drama_client/features/wallet/data/wallet_repository_provider.dart';
import 'package:drama_client/features/wallet/domain/wallet_record.dart';
import 'package:drama_client/features/wallet/domain/wallet_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads wallet balances and records', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(walletControllerProvider.notifier).load();

    final state = container.read(walletControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.coins, 120);
    expect(state.bonus, 4000);
    expect(state.transactionRecords, hasLength(3));
    expect(state.recordsFor(WalletRecordType.consumption), hasLength(3));
  });

  test('loads empty wallet record lists', () async {
    final container = _createContainer(_FakeWalletRepository(_emptyWalletData));

    await container.read(walletControllerProvider.notifier).load();
    final state = container.read(walletControllerProvider);

    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.transactionRecords, isEmpty);
    expect(state.consumptionRecords, isEmpty);
    expect(state.coinRecords, isEmpty);
  });

  test('keeps wallet error retryable', () async {
    final repository = _FakeWalletRepository(_emptyWalletData)
      ..shouldThrow = true;
    final container = _createContainer(repository);
    final controller = container.read(walletControllerProvider.notifier);

    await controller.load();
    var state = container.read(walletControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isA<StateError>());

    repository.shouldThrow = false;
    await controller.retry();
    state = container.read(walletControllerProvider);

    expect(state.error, isNull);
    expect(state.transactionRecords, isEmpty);
  });

  test('toggles auto unlock next episode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isFalse,
    );

    await controller.setAutoUnlockNextEpisode(true);

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isTrue,
    );
    expect(
      container.read(entitlementControllerProvider).autoUnlockEnabled,
      isTrue,
    );
  });

  test('keeps local auto unlock choice when wallet reloads', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();
    await controller.setAutoUnlockNextEpisode(true);
    await controller.load();

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isTrue,
    );
    expect(
      container.read(entitlementControllerProvider).autoUnlockEnabled,
      isTrue,
    );
  });

  test('filters consumption records and claims reward coins locally', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();
    controller.setConsumptionFilter(WalletConsumptionStatus.expired);

    expect(
      container.read(walletControllerProvider).consumptionFilter,
      WalletConsumptionStatus.expired,
    );

    controller.claimReward('daily_bonus');
    final reward = container.read(walletControllerProvider).coinRecords.first;
    expect(reward.rewardClaimed, isTrue);
    expect(reward.rewardEnabled, isFalse);
  });
}

ProviderContainer _createContainer(WalletRepository repository) {
  final container = ProviderContainer(
    overrides: [walletRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository(this.data);

  final WalletData data;
  bool shouldThrow = false;

  @override
  Future<WalletData> fetchWallet() async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    return data;
  }
}

const _emptyWalletData = WalletData(
  coins: 0,
  bonus: 0,
  autoUnlockNextEpisode: false,
  transactionRecords: [],
  consumptionRecords: [],
  coinRecords: [],
);
