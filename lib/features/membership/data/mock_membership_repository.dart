import '../domain/membership_plan.dart';
import '../domain/membership_repository.dart';

class MockMembershipRepository implements MembershipRepository {
  const MockMembershipRepository();

  @override
  Future<MembershipData> fetchMembership({required int userId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    return const MembershipData(
      isActive: false,
      heroTitle: 'Join Membership',
      heroSubtitle: '10M+ users upgraded',
      plans: [
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
      benefits: [
        MembershipBenefit(
          icon: MembershipBenefitIcon.series,
          title: 'Unlimited access to ',
          highlight: '8,000+ series',
          description: '55+ fresh dramas every week',
        ),
        MembershipBenefit(
          icon: MembershipBenefitIcon.download,
          title: 'Download',
        ),
        MembershipBenefit(
          icon: MembershipBenefitIcon.points,
          title: 'Daily member points',
        ),
        MembershipBenefit(
          icon: MembershipBenefitIcon.membersOnly,
          title: 'Members-only dramas',
        ),
        MembershipBenefit(
          icon: MembershipBenefitIcon.hd,
          title: '1080p quality',
        ),
        MembershipBenefit(icon: MembershipBenefitIcon.adFree, title: 'Ad-free'),
      ],
      tips: MembershipTips(
        subscriptionNote:
            'By subscribing, you agree to our Terms of Use: Apple Standard EULA',
        items: [
          'Coin=1 Bonus. Deduct bonus first when unlocking.',
          'Coins are irrevocable virtual assets. Please use them within this product.',
          'The purchased game coins are yet to be credited, Please click the icon to restart the app.',
          'The rewarded bonuses have an expiration date. Please use them before they expire.',
          'Subscription plans: auto renew, cancel anytime.',
          'Subscriptions can also be managed through Apple',
        ],
      ),
    );
  }
}
