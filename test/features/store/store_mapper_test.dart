import 'package:drama_client/features/store/data/dto/member_product_dto.dart';
import 'package:drama_client/features/store/data/mapper/store_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps memberType on the store VIP package', () {
    final package = const StoreMapper().mapMemberProduct(
      MemberProductDto.fromJson({
        'productId': '2',
        'channelProductId': 'member_lifetime',
        'currencySymbol': r'$',
        'memberType': 'MEMBER_PRODUCT_TYPE_ONE_TIME',
        'payChannel': 'PAY_CHANNEL_GOOGLE',
        'periodType': '',
        'periodValue': 0,
        'priceText': '9.99',
        'sort': 1,
        'status': 1,
        'createdAt': '2026-07-30T00:00:00Z',
        'updatedAt': '2026-07-30T00:00:00Z',
      }),
    );

    expect(package.memberType, 'MEMBER_PRODUCT_TYPE_ONE_TIME');
  });
}
