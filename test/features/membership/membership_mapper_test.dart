import 'package:drama_client/features/membership/data/dto/membership_product_dto.dart';
import 'package:drama_client/features/membership/data/mapper/membership_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps memberType on the membership plan', () {
    final plan = const MembershipMapper().mapProduct(
      MembershipProductDto.fromJson({
        'productId': 2,
        'productName': 'Lifetime VIP',
        'channelProductId': 'member_lifetime',
        'currencySymbol': r'$',
        'memberType': 'MEMBER_PRODUCT_TYPE_ONE_TIME',
        'priceText': '9.99',
        'originalPriceText': '9.99',
        'periodType': '',
        'periodValue': 0,
        'payChannel': 'PAY_CHANNEL_GOOGLE',
        'status': 0,
        'sort': 1,
      }),
    );

    expect(plan.memberType, 'MEMBER_PRODUCT_TYPE_ONE_TIME');
  });
}
