import 'package:drama_client/features/wallet/application/wallet_controller.dart';
import 'package:drama_client/features/wallet/domain/wallet_record.dart';
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

  test('toggles auto unlock next episode', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isTrue,
    );

    controller.setAutoUnlockNextEpisode(false);

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isFalse,
    );
  });

  test('keeps local auto unlock choice when wallet reloads', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(walletControllerProvider.notifier);
    await controller.load();
    controller.setAutoUnlockNextEpisode(false);
    await controller.load();

    expect(
      container.read(walletControllerProvider).autoUnlockNextEpisode,
      isFalse,
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
