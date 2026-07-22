import 'package:drama_client/features/pay/domain/iap_product_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IapPromoTextBuilder', () {
    test('builds the requested Chinese and English paid-promo copy', () {
      expect(
        IapPromoTextBuilder.build(
          promoPrice: r'$14.99',
          promoPeriod: 'P1W',
          promoCycles: 2,
          regularPrice: r'$19.99',
          regularPeriod: 'P1W',
          hasFreeTrial: false,
          languageCode: 'zh-CN',
        ),
        r'前2周 $14.99/周，之后 $19.99/周。',
      );
      expect(
        IapPromoTextBuilder.build(
          promoPrice: r'$14.99',
          promoPeriod: 'P1W',
          promoCycles: 2,
          regularPrice: r'$19.99',
          regularPeriod: 'P1W',
          hasFreeTrial: false,
          languageCode: 'en-US',
        ),
        r'$14.99/week for first 2 weeks, then $19.99/week',
      );
    });
  });
}
