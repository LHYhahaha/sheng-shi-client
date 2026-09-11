import '../domain/store_package.dart';
import '../domain/store_repository.dart';

class MockStoreRepository implements StoreRepository {
  const MockStoreRepository();

  @override
  Future<StoreRechargeData> fetchRechargeData() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    return const StoreRechargeData(
      balance: 60,
      coinPackages: [
        StorePackage(
          id: 'coins_2000',
          kind: StorePackageKind.coins,
          title: '2000',
          baseCoins: 2000,
          priceLabel: r'$ 19.99',
        ),
        StorePackage(
          id: 'coins_3000_bonus',
          kind: StorePackageKind.coins,
          title: '3000',
          baseCoins: 3000,
          bonusCoins: 300,
          bonusLabel: '+300 Bonus',
          badgeLabel: '+10%',
          priceLabel: r'$ 29.99',
        ),
        StorePackage(
          id: 'coins_3000',
          kind: StorePackageKind.coins,
          title: '3000',
          baseCoins: 3000,
          bonusCoins: 300,
          bonusLabel: '+300 Bonus',
          priceLabel: r'$ 29.99',
        ),
      ],
      vipPackages: [
        StorePackage(
          id: 'weekly_vip_intro',
          kind: StorePackageKind.vip,
          title: 'Weekly VIP',
          subtitle: 'Auto renew · Cancel anytime',
          footnote: r'$14.99 for 1st week,then $19.99 per',
          priceLabel: r'$14.99',
          originalPriceLabel: r'$19.99',
          badgeLabel: '23:59:59',
          benefits: [
            StorePackageBenefit(icon: StoreBenefitIcon.drama),
            StorePackageBenefit(icon: StoreBenefitIcon.ad),
            StorePackageBenefit(icon: StoreBenefitIcon.hd),
            StorePackageBenefit(icon: StoreBenefitIcon.points),
          ],
        ),
        StorePackage(
          id: 'weekly_vip',
          kind: StorePackageKind.vip,
          title: 'Weekly VIP',
          subtitle: 'Auto renew · Cancel anytime',
          priceLabel: r'$14.99',
          benefits: [
            StorePackageBenefit(icon: StoreBenefitIcon.drama),
            StorePackageBenefit(icon: StoreBenefitIcon.ad),
            StorePackageBenefit(icon: StoreBenefitIcon.hd),
            StorePackageBenefit(icon: StoreBenefitIcon.points),
          ],
        ),
      ],
      tips: StoreTips(
        linksLabel: 'Privacy policy    ·    Terms of use',
        subscriptionNote:
            'By subscribing, you agree to our Terms of Use: Apple Standard EULA',
        items: [
          'Coin=1 Bonus. Deduct bonus first when unlocking.',
          'Coins are irrevocable virtual assets. Please use them within this product.',
          'The purchased game coins are yet to be credited, Please click the icon to restart the app.',
          'The rewarded bonuses have an expiration date. Please use them before they expire.',
          'Subscription plans: auto renew, cancel anytime.',
        ],
      ),
    );
  }
}
