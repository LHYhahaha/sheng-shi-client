import 'package:drama_client/features/pay/domain/member_product_type.dart';
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
}
