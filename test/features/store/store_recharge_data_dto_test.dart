import 'package:drama_client/features/store/data/dto/store_recharge_data_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses newly added recharge page payment fields', () {
    final dto = StoreRechargeDataDto.fromJson({
      'coin': 100,
      'bonusCoin': 20,
      'requiredCoin': 50,
      'coinProducts': [
        {
          'productId': 1,
          'coin': 100,
          'bonusCoin': 20,
          'bonusExpireDays': 7,
          'bonusExpireEnabled': true,
          'channelProductId': 'coins_100',
          'currencySymbol': r'$',
          'payChannel': 'PAY_CHANNEL_GOOGLE',
          'priceText': r'$0.99',
          'productName': '100 coins',
          'sort': 1,
          'status': 1,
          'createdAt': '2026-07-30T00:00:00Z',
          'updatedAt': '2026-07-30T00:00:00Z',
        },
      ],
      'memberProducts': [
        {
          'productId': 2,
          'channelProductId': 'member_monthly',
          'currencySymbol': r'$',
          'memberType': 'MEMBER_PRODUCT_TYPE_SUBSCRIPTION',
          'payChannel': 'PAY_CHANNEL_GOOGLE',
          'periodType': 'MEMBER_PERIOD_TYPE_MONTH',
          'periodValue': 1,
          'priceText': r'$4.99',
          'originalPriceText': r'$9.99',
          'productName': 'Monthly VIP',
          'promotionExpireSeconds': 3600,
          'promotionText': '50% off',
          'sort': 1,
          'status': 1,
          'createdAt': '2026-07-30T00:00:00Z',
          'updatedAt': '2026-07-30T00:00:00Z',
        },
      ],
    });

    expect(dto.balance, 100);
    expect(dto.coinProducts.single.currencySymbol, r'$');
    expect(
      dto.memberProducts.single.memberType,
      'MEMBER_PRODUCT_TYPE_SUBSCRIPTION',
    );
    expect(dto.memberProducts.single.promotionExpireSeconds, 3600);
  });
}
