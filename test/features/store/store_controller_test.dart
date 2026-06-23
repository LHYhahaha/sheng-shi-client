import 'package:drama_client/features/store/application/store_controller.dart';
import 'package:drama_client/features/store/data/store_repository_provider.dart';
import 'package:drama_client/features/store/domain/store_package.dart';
import 'package:drama_client/features/store/domain/store_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads store packages from repository', () async {
    final container = _container();
    addTearDown(container.dispose);

    await container.read(storeControllerProvider.notifier).load();

    final state = container.read(storeControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.coinPackages, hasLength(2));
    expect(state.vipPackages, hasLength(1));
    expect(state.selectedPackage?.id, 'coins_2000');
  });

  test('selects package and opens confirmation state', () async {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(storeControllerProvider.notifier);

    await controller.load();
    controller.selectPackage('coins_3000_bonus');
    controller.showConfirmation();

    final state = container.read(storeControllerProvider);
    expect(state.selectedPackage?.id, 'coins_3000_bonus');
    expect(state.confirmationPackage?.title, '3000');

    controller.hideConfirmation();
    expect(container.read(storeControllerProvider).confirmationPackage, isNull);
    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.idle,
    );
  });

  test('cancel purchase only affects idle confirmation flow', () async {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(storeControllerProvider.notifier);

    await controller.load();
    controller.showConfirmation();
    controller.cancelPurchase();

    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.cancelled,
    );

    controller.hideConfirmation();
    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.idle,
    );
  });

  test('confirm purchase fails fast when user info is missing', () async {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(storeControllerProvider.notifier);

    await controller.load();
    controller.showConfirmation();
    await controller.confirmPurchase();

    final state = container.read(storeControllerProvider);
    expect(state.purchaseStatus, StorePurchaseStatus.failed);
    expect(state.error, isNotNull);
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      storeRepositoryProvider.overrideWithValue(const _FakeStoreRepository()),
    ],
  );
}

class _FakeStoreRepository implements StoreRepository {
  const _FakeStoreRepository();

  @override
  Future<StoreRechargeData> fetchRechargeData() async {
    return const StoreRechargeData(
      balance: 60,
      coinPackages: [
        StorePackage(
          id: 'coins_2000',
          kind: StorePackageKind.coins,
          title: '2000',
          baseCoins: 2000,
          priceLabel: r'$19.99',
        ),
        StorePackage(
          id: 'coins_3000_bonus',
          kind: StorePackageKind.coins,
          title: '3000',
          baseCoins: 3000,
          bonusCoins: 300,
          bonusLabel: '+300 Bonus',
          priceLabel: r'$29.99',
        ),
      ],
      vipPackages: [
        StorePackage(
          id: 'weekly_vip',
          kind: StorePackageKind.vip,
          title: 'Weekly VIP',
          priceLabel: r'$14.99',
        ),
      ],
      tips: StoreTips(
        linksLabel: 'Privacy policy',
        subscriptionNote: 'Auto renew. Cancel anytime.',
        items: ['Prices may vary by region.'],
      ),
    );
  }
}
