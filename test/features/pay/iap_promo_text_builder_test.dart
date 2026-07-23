import 'package:drama_client/core/utils/period_iso_parser.dart';
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
        r'$14.99 for 2nd week, then $19.99 week',
      );
    });

    test('uses ordinal suffixes for English promo durations', () {
      for (final expectation in <int, String>{
        1: '1st',
        2: '2nd',
        3: '3rd',
        4: '4th',
        5: '5th',
      }.entries) {
        expect(
          IapPromoTextBuilder.build(
            promoPrice: r'$1.99',
            promoPeriod: 'P1W',
            promoCycles: expectation.key,
            regularPrice: r'$9.99',
            regularPeriod: 'P1W',
            hasFreeTrial: false,
            languageCode: 'en-US',
          ),
          '\$1.99 for ${expectation.value} week, then \$9.99 week',
        );
      }
    });
  });
}
