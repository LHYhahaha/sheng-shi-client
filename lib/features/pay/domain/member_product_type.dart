/// Backend member product type helpers.
///
/// Unknown values intentionally remain unchanged for analytics so backend
/// additions are observable without the client reclassifying the product.
abstract final class MemberProductType {
  static const oneTime = 'MEMBER_PRODUCT_TYPE_ONE_TIME';
  static const subscription = 'MEMBER_PRODUCT_TYPE_SUBSCRIPTION';

  static String analyticsProductTypeFor(String memberType) =>
      switch (memberType) {
        oneTime => 'vip_once',
        subscription => 'vip_subscription',
        _ => memberType,
      };

  static bool usesGoogleSubscriptionOffer(String memberType) =>
      memberType == subscription;
}
