import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/store/application/store_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads store packages from repository', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(storeControllerProvider.notifier).load();

    final state = container.read(storeControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.coinPackages, hasLength(3));
    expect(state.vipPackages, hasLength(2));
    expect(state.selectedPackage?.id, 'coins_2000');
  });

  test('selects package and opens mock confirmation state', () async {
    final container = ProviderContainer();
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
  });

  test('tracks mock purchase processing, success, and cancel states', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(storeControllerProvider.notifier);

    await controller.load();
    controller.showConfirmation();

    final purchase = controller.confirmMockPurchase();
    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.processing,
    );

    await purchase;
    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.success,
    );

    controller.hideConfirmation();
    controller.showConfirmation();
    controller.cancelMockPurchase();

    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.cancelled,
    );
  });

  test('ignores repeated actions while purchase is processing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(storeControllerProvider.notifier);

    await controller.load();
    controller.showConfirmation();

    final purchase = controller.confirmMockPurchase();
    controller.confirmMockPurchase();
    controller.cancelMockPurchase();

    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.processing,
    );

    await purchase;
    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.success,
    );

    controller.cancelMockPurchase();
    expect(
      container.read(storeControllerProvider).purchaseStatus,
      StorePurchaseStatus.success,
    );
  });

  test(
    'resets purchase status when confirmation is closed or reopened',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(storeControllerProvider.notifier);

      await controller.load();
      controller.showConfirmation();
      controller.cancelMockPurchase();
      expect(
        container.read(storeControllerProvider).purchaseStatus,
        StorePurchaseStatus.cancelled,
      );

      controller.hideConfirmation();
      var state = container.read(storeControllerProvider);
      expect(state.confirmationPackage, isNull);
      expect(state.purchaseStatus, StorePurchaseStatus.idle);

      controller.selectPackage('coins_3000_bonus');
      controller.showConfirmation();
      state = container.read(storeControllerProvider);

      expect(state.confirmationPackage?.id, 'coins_3000_bonus');
      expect(state.purchaseStatus, StorePurchaseStatus.idle);
    },
  );

  test(
    'closing confirmation cancels pending mock purchase completion',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(storeControllerProvider.notifier);

      await controller.load();
      controller.showConfirmation();

      final purchase = controller.confirmMockPurchase();
      controller.hideConfirmation();
      await purchase;

      final state = container.read(storeControllerProvider);
      expect(state.confirmationPackage, isNull);
      expect(state.purchaseStatus, StorePurchaseStatus.idle);
    },
  );

  test(
    'coin purchase success grants coins to shared entitlement state',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(storeControllerProvider.notifier);

      await controller.load();
      controller.selectPackage('coins_3000_bonus');
      controller.showConfirmation();
      await controller.confirmMockPurchase();

      expect(
        container.read(storeControllerProvider).purchaseStatus,
        StorePurchaseStatus.success,
      );
      expect(container.read(entitlementControllerProvider).coinBalance, 7300);
    },
  );

  test(
    'vip purchase success grants membership to shared entitlement state',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(storeControllerProvider.notifier);

      await controller.load();
      controller.selectPackage('weekly_vip_intro');
      controller.showConfirmation();
      await controller.confirmMockPurchase();

      expect(
        container.read(storeControllerProvider).purchaseStatus,
        StorePurchaseStatus.success,
      );
      expect(container.read(entitlementControllerProvider).isMember, isTrue);
    },
  );
}
