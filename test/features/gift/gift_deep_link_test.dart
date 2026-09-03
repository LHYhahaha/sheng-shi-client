import 'package:drama_client/features/gift/application/gift_deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a drama gift deep link', () {
    final link = GiftDeepLink.tryParse(
      Uri.parse(
        'novashort://player?drama_id=1506&landing_type=drama_gift&shareCode=abc123',
      ),
    );

    expect(link?.type, GiftDeepLinkType.drama);
    expect(link?.dramaId, '1506');
    expect(link?.shareCode, 'abc123');
  });

  test('parses a temporary VIP gift deep link without a drama id', () {
    final link = GiftDeepLink.tryParse(
      Uri.parse(
        'novashort://player?landing_type=temp_vip_gift&shareCode=abc123',
      ),
    );

    expect(link?.type, GiftDeepLinkType.temporaryVip);
    expect(link?.dramaId, isNull);
    expect(link?.shareCode, 'abc123');
  });

  test('rejects incomplete or unsupported gift links', () {
    expect(
      GiftDeepLink.tryParse(
        Uri.parse('novashort://player?landing_type=drama_gift'),
      ),
      isNull,
    );
    expect(
      GiftDeepLink.tryParse(
        Uri.parse('novashort://player?landing_type=unknown&shareCode=abc'),
      ),
      isNull,
    );
  });
}
