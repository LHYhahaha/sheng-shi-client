import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';

class MockMembershipRepository implements MembershipRepository {
  const MockMembershipRepository();

  @override
  Future<MembershipData> fetchMembership() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    return MembershipData(
      isActive: false,
      heroTitle: 'Join Membership',
      heroSubtitle: '10M+ users upgraded',
      plans: const [
        MembershipPlan(
          id: 'weekly_vip',
          title: 'Weekly VIP',
          priceLabel: r'$12.99',
          originalPriceLabel: r'$24.99',
          dailyPriceLabel: r'$1.78/day',
          badgeLabel: '23:59:59',
          description: r'$12.99 for the first week, then $24.99/week',
        ),
        MembershipPlan(
          id: 'monthly_vip',
          title: 'Monthly VIP',
          priceLabel: r'$39.99',
          dailyPriceLabel: r'$1.23/day',
        ),
        MembershipPlan(
          id: 'yearly_vip',
          title: 'Yearly VIP',
          priceLabel: r'$39.99',
          dailyPriceLabel: r'$0.82/day',
        ),
      ],
    );
  }
}
