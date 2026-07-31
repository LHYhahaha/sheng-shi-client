import 'package:drama_client/features/membership/data/dto/membership_product_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses current member page product fields', () {
    final dto = MembershipProductDto.fromJson({
      'productId': 2,
      'productName': 'Monthly VIP',
      'channelProductId': 'member_monthly',
      'currencySymbol': r'$',
      'memberType': 'MEMBER_PRODUCT_TYPE_SUBSCRIPTION',
      'priceText': r'$4.99',
      'originalPriceText': r'$9.99',
      'periodType': 'MEMBER_PERIOD_TYPE_MONTH',
      'periodValue': 1,
      'payChannel': 'PAY_CHANNEL_GOOGLE',
      'promotionText': '50% off',
      'promotionExpireSeconds': 3600,
      'sort': 1,
      'status': 1,
      'createdAt': '2026-07-30T00:00:00Z',
      'updatedAt': '2026-07-30T00:00:00Z',
    });

    expect(dto.currencySymbol, r'$');
    expect(dto.memberType, 'MEMBER_PRODUCT_TYPE_SUBSCRIPTION');
    expect(dto.periodType, 'MEMBER_PERIOD_TYPE_MONTH');
    expect(dto.payChannel, 'PAY_CHANNEL_GOOGLE');
    expect(dto.promotionExpireSeconds, 3600);
  });
}
