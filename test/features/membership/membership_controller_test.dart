import 'package:drama_client/features/membership/application/membership_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads membership plans and benefits', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(membershipControllerProvider.notifier).load();

    final state = container.read(membershipControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.plans, hasLength(3));
    expect(state.benefits, hasLength(6));
    expect(state.selectedPlan?.id, 'weekly_vip');
  });

  test('selects membership plan and opens confirmation state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(membershipControllerProvider.notifier);

    await controller.load();
    controller.selectPlan('monthly_vip');
    controller.showConfirmation();

    final state = container.read(membershipControllerProvider);
    expect(state.selectedPlan?.title, 'Monthly VIP');
    expect(state.confirmationPlan?.priceLabel, r'$39.99');

    controller.hideConfirmation();
    expect(
      container.read(membershipControllerProvider).confirmationPlan,
      isNull,
    );
  });

  test(
    'tracks mock membership purchase processing, success, and cancel states',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(membershipControllerProvider.notifier);

      await controller.load();
      controller.showConfirmation();

      final purchase = controller.confirmMockPurchase();
      expect(
        container.read(membershipControllerProvider).purchaseStatus,
        MembershipPurchaseStatus.processing,
      );

      await purchase;
      expect(
        container.read(membershipControllerProvider).purchaseStatus,
        MembershipPurchaseStatus.success,
      );

      controller.hideConfirmation();
      controller.showConfirmation();
      controller.cancelMockPurchase();

      expect(
        container.read(membershipControllerProvider).purchaseStatus,
        MembershipPurchaseStatus.cancelled,
      );
    },
  );
}
