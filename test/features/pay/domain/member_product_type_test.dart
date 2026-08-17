import 'package:drama_client/features/pay/domain/member_product_type.dart';
import 'package:drama_client/features/player/domain/player_recharge_unlock_offer.dart';
import 'package:drama_client/features/store/domain/store_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps one-time member products to the one-time analytics type', () {
    expect(
      MemberProductType.analyticsProductTypeFor('MEMBER_PRODUCT_TYPE_ONE_TIME'),
      'vip_once',
    );
  });

  test(
    'maps subscription member products to the subscription analytics type',
    () {
      expect(
        MemberProductType.analyticsProductTypeFor(
          'MEMBER_PRODUCT_TYPE_SUBSCRIPTION',
        ),
        'vip_subscription',
      );
    },
  );

  test('preserves unknown member product types for analytics', () {
    expect(
      MemberProductType.analyticsProductTypeFor('MEMBER_PRODUCT_TYPE_TRIAL'),
      'MEMBER_PRODUCT_TYPE_TRIAL',
    );
  });

  test('only subscriptions use a Google Play offer token', () {
    expect(
      MemberProductType.usesGoogleSubscriptionOffer(
        'MEMBER_PRODUCT_TYPE_ONE_TIME',
      ),
      isFalse,
    );
    expect(
      MemberProductType.usesGoogleSubscriptionOffer(
        'MEMBER_PRODUCT_TYPE_SUBSCRIPTION',
      ),
      isTrue,
    );
    expect(
      MemberProductType.usesGoogleSubscriptionOffer(
        'MEMBER_PRODUCT_TYPE_TRIAL',
      ),
      isFalse,
    );
  });

  test(
    'shows the auto-renew notice only for subscription membership cards',
    () {
      const subscriptionStorePackage = StorePackage(
        id: 'subscription',
        kind: StorePackageKind.vip,
        title: 'Monthly VIP',
        priceLabel: r'$4.99',
        memberType: MemberProductType.subscription,
      );
      const oneTimeStorePackage = StorePackage(
        id: 'one-time',
        kind: StorePackageKind.vip,
        title: 'Lifetime VIP',
        priceLabel: r'$19.99',
        memberType: MemberProductType.oneTime,
      );
      const unknownStorePackage = StorePackage(
        id: 'unknown',
        kind: StorePackageKind.vip,
        title: 'VIP',
        priceLabel: r'$9.99',
        memberType: 'MEMBER_PRODUCT_TYPE_TRIAL',
      );
      const subscriptionPlayerPackage = PlayerRechargeMembershipPackage(
        id: 'subscription',
        periodLabel: 'Monthly',
        googleProductId: 'member_monthly',
        googlePriceLabel: r'$4.99',
        memberType: MemberProductType.subscription,
      );
      const oneTimePlayerPackage = PlayerRechargeMembershipPackage(
        id: 'one-time',
        periodLabel: 'Lifetime',
        googleProductId: 'member_lifetime',
        googlePriceLabel: r'$19.99',
        memberType: MemberProductType.oneTime,
      );

      expect(subscriptionStorePackage.showsAutoRenewNotice, isTrue);
      expect(oneTimeStorePackage.showsAutoRenewNotice, isFalse);
      expect(unknownStorePackage.showsAutoRenewNotice, isFalse);
      expect(subscriptionPlayerPackage.showsAutoRenewNotice, isTrue);
      expect(oneTimePlayerPackage.showsAutoRenewNotice, isFalse);
    },
  );
}
