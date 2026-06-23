import 'package:drama_client/features/membership/application/membership_controller.dart';
import 'package:drama_client/features/membership/data/membership_repository_provider.dart';
import 'package:drama_client/features/membership/domain/membership_plan.dart';
import 'package:drama_client/features/membership/domain/membership_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads membership plans from repository', () async {
    final container = _container();
    addTearDown(container.dispose);

    await container.read(membershipControllerProvider.notifier).load();

    final state = container.read(membershipControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.plans, hasLength(3));
    expect(state.selectedPlan?.id, 'weekly_vip');
  });

  test('selects membership plan and opens confirmation state', () async {
    final container = _container();
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
    expect(
      container.read(membershipControllerProvider).purchaseStatus,
      MembershipPurchaseStatus.idle,
    );
  });

  test('cancel purchase only affects idle confirmation flow', () async {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(membershipControllerProvider.notifier);

    await controller.load();
    controller.showConfirmation();
    controller.cancelPurchase();

    expect(
      container.read(membershipControllerProvider).purchaseStatus,
      MembershipPurchaseStatus.cancelled,
    );

    controller.hideConfirmation();
    expect(
      container.read(membershipControllerProvider).purchaseStatus,
      MembershipPurchaseStatus.idle,
    );
  });

  test('confirm purchase fails fast when user info is missing', () async {
    final container = _container();
    addTearDown(container.dispose);
    final controller = container.read(membershipControllerProvider.notifier);

    await controller.load();
    controller.showConfirmation();
    await controller.confirmPurchase();

    final state = container.read(membershipControllerProvider);
    expect(state.purchaseStatus, MembershipPurchaseStatus.failed);
    expect(state.error, isNotNull);
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      membershipRepositoryProvider.overrideWithValue(
        const _FakeMembershipRepository(),
      ),
    ],
  );
}

class _FakeMembershipRepository implements MembershipRepository {
  const _FakeMembershipRepository();

  @override
  Future<MembershipData> fetchMembership() async {
    return const MembershipData(
      isActive: false,
      heroTitle: 'Join Membership',
      heroSubtitle: '10M+ users upgraded',
      plans: [
        MembershipPlan(
          id: 'weekly_vip',
          title: 'Weekly VIP',
          priceLabel: r'$14.99',
          dailyPriceLabel: r'$2.14/day',
          period: 'P1W',
        ),
        MembershipPlan(
          id: 'monthly_vip',
          title: 'Monthly VIP',
          priceLabel: r'$39.99',
          dailyPriceLabel: r'$1.33/day',
          period: 'P1M',
        ),
        MembershipPlan(
          id: 'yearly_vip',
          title: 'Yearly VIP',
          priceLabel: r'$99.99',
          dailyPriceLabel: r'$0.27/day',
          period: 'P1Y',
        ),
      ],
    );
  }
}
