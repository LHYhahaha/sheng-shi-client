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
    expect(state.coins, 4000);
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

  test('loads more transaction records when next page exists', () async {
    final repository = _FakeWalletRepository(
      _emptyWalletData,
      transactionPages: [
        WalletRecordPage(
          items: [_transactionRecordA],
          nextPageToken: '2',
        ),
        WalletRecordPage(
          items: [_transactionRecordB],
          nextPageToken: null,
        ),
      ],
    );
    final container = _createContainer(repository);
    final controller = container.read(walletControllerProvider.notifier);

    await controller.loadTransactionRecords();
    var state = container.read(walletControllerProvider);
    expect(state.transactionRecords.map((record) => record.id), ['tx-a']);
    expect(state.transactionNextPageToken, '2');

    await controller.loadMoreRecords(WalletRecordType.transaction);
    state = container.read(walletControllerProvider);

    expect(state.transactionRecords.map((record) => record.id), [
      'tx-a',
      'tx-b',
    ]);
    expect(state.transactionNextPageToken, isNull);
    expect(state.isHistoryLoadingMore, isFalse);
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
      isTrue,
    );

    await controller.setAutoUnlockNextEpisode(false);

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isFalse,
    );
    expect(
      container.read(entitlementControllerProvider).autoUnlockEnabled,
      isFalse,
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
  _FakeWalletRepository(
    this.data, {
    this.transactionPages,
    this.consumptionPages,
    this.rewardPages,
  });

  final WalletData data;
  final List<WalletRecordPage>? transactionPages;
  final List<WalletRecordPage>? consumptionPages;
  final List<WalletRecordPage>? rewardPages;
  bool shouldThrow = false;

  @override
  Future<WalletData> fetchWallet() async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    return data;
  }

  @override
  Future<WalletRecordPage> fetchTransactionRecords({
    String? pageToken,
  }) async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    final pageIndex = (int.tryParse(pageToken ?? '1') ?? 1) - 1;
    if (transactionPages != null) {
      return transactionPages![pageIndex];
    }
    return const WalletRecordPage(items: [], nextPageToken: null);
  }

  @override
  Future<WalletRecordPage> fetchConsumptionRecords({
    required String status,
    String? pageToken,
  }) async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    final pageIndex = (int.tryParse(pageToken ?? '1') ?? 1) - 1;
    if (consumptionPages != null) {
      return consumptionPages![pageIndex];
    }
    return const WalletRecordPage(items: [], nextPageToken: null);
  }

  @override
  Future<WalletRecordPage> fetchRewardCoins({
    String? pageToken,
  }) async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    final pageIndex = (int.tryParse(pageToken ?? '1') ?? 1) - 1;
    if (rewardPages != null) {
      return rewardPages![pageIndex];
    }
    return const WalletRecordPage(items: [], nextPageToken: null);
  }
}

final _transactionRecordA = WalletRecord.raw(
  id: 'tx-a',
  type: WalletRecordType.transaction,
  title: 'Coins A',
  dateLabel: '2026.06.24',
  trailingLabel: r'$1.99',
);

final _transactionRecordB = WalletRecord.raw(
  id: 'tx-b',
  type: WalletRecordType.transaction,
  title: 'Coins B',
  dateLabel: '2026.06.24',
  trailingLabel: r'$2.99',
);

const _emptyWalletData = WalletData(
  coins: 0,
  bonus: 0,
  totalCoin: 0,
  autoUnlockNextEpisode: false,
  transactionRecords: [],
  consumptionRecords: [],
  coinRecords: [],
);
