import 'package:drama_client/features/pay/data/dto/payment_order_options_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps payment rule fields from order options response', () {
    final dto = PaymentOrderOptionsDto.fromJson({
      'countryCode': 'US',
      'defaultMethodCode': 'google_play',
      'directPay': false,
      'options': [
        {
          'actionType': 'GOOGLE_PLAY',
          'actionUrl': '',
          'amountMicros': '9990000',
          'channelProductId': 'com.example.product',
          'currency': r'$',
          'methodCode': 'google_play',
          'methodName': 'Google Play',
          'originalPriceText': r'$12.99',
          'payChannel': 'PAY_CHANNEL_GOOGLE',
          'priceSource': 1,
          'priceText': r'$9.99',
          'productDependency': '',
          'promotionAmountMicros': '3000000',
          'promotionPriceText': r'$9.99',
          'promotionText': 'Limited offer',
          'sort': 1,
          'supportRefund': true,
        },
      ],
      'osType': 'CLIENT_OS_TYPE_ANDROID',
      'payScene': 'PAYMENT_SCENE_ONE_TIME',
      'productId': '123',
      'productType': 'PRODUCT_TYPE_COIN',
      'ruleId': '456',
      'ruleName': 'US Google Play rule',
      'showCashier': true,
    });

    expect(dto.ruleId, 456);
    expect(dto.ruleName, 'US Google Play rule');
    expect(dto.toDomain().ruleId, 456);
    expect(dto.toDomain().ruleName, 'US Google Play rule');
  });
}
