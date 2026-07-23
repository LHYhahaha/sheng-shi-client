import 'package:drama_client/core/utils/period_iso_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodIsoParser commerce labels', () {
    test('builds localized promo descriptions', () {
      expect(
        PeriodIsoParser.buildPromoDescription(
          promoPrice: r'$14.99',
          regularPrice: r'$19.99',
          promoPeriodIso: 'P2W',
          regularPeriodIso: 'P1W',
          languageCode: 'en',
        ),
        r'$14.99 for 2nd week, then $19.99 week',
      );

      expect(
        PeriodIsoParser.buildPromoDescription(
          promoPrice: r'$14.99',
          regularPrice: r'$19.99',
          promoPeriodIso: 'P2W',
          regularPeriodIso: 'P1W',
          languageCode: 'zh',
        ),
        '\u524d2\u5468 \$14.99/\u5468\uff0c\u4e4b\u540e \$19.99/\u5468\u3002',
      );
    });

    test('localizes membership titles', () {
      expect(
        PeriodIsoParser.localizedMembershipTitle(
          'Weekly VIP',
          languageCode: 'en',
        ),
        'Weekly VIP',
      );
      expect(
        PeriodIsoParser.localizedMembershipTitle(
          'Weekly VIP',
          languageCode: 'zh',
        ),
        '\u5468\u4f1a\u5458',
      );
      expect(
        PeriodIsoParser.localizedMembershipTitle(
          'VIP',
          periodIso: 'P3M',
          languageCode: 'en',
        ),
        'Quarterly VIP',
      );
    });

    test('localizes daily price suffix', () {
      expect(
        PeriodIsoParser.localizedDailyPriceLabel(
          r'$1.78/day',
          languageCode: 'zh',
        ),
        '\$1.78/\u5929',
      );
      expect(
        PeriodIsoParser.localizedDailyPriceLabel(
          '\$1.78/\u5929',
          languageCode: 'en',
        ),
        r'$1.78/day',
      );
    });
  });
}
