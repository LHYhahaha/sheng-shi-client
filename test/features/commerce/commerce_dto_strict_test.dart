import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/features/membership/data/dto/membership_product_dto.dart';
import 'package:drama_client/features/store/data/dto/order_dto.dart';
import 'package:drama_client/features/store/data/dto/store_recharge_product_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store product missing productId throws', () {
    expect(
      () => StoreRechargeProductDto.fromJson({
        'platformProductId': 'google.coins.1',
        'priceMicros': 100,
        'currencyCode': 'USD',
        'enabled': true,
        'baseCoins': 1,
        'bonusCoins': 0,
        'totalCoins': 1,
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('store product missing priceMicros throws', () {
    expect(
      () => StoreRechargeProductDto.fromJson({
        'productId': 'coins-1',
        'platformProductId': 'google.coins.1',
        'currencyCode': 'USD',
        'enabled': true,
        'baseCoins': 1,
        'bonusCoins': 0,
        'totalCoins': 1,
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('enabled missing does not default to true', () {
    expect(
      () => StoreRechargeProductDto.fromJson({
        'productId': 'coins-1',
        'platformProductId': 'google.coins.1',
        'priceMicros': 100,
        'currencyCode': 'USD',
        'baseCoins': 1,
        'bonusCoins': 0,
        'totalCoins': 1,
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('unknown order status throws', () {
    expect(
      () => OrderDto.fromJson({
        'orderId': 'order-1',
        'productId': 'coins-1',
        'status': 'mystery',
        'amountMicros': 999,
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('membership product enabled missing throws', () {
    expect(
      () => MembershipProductDto.fromJson({
        'productId': 'weekly',
        'platformProductId': 'google.weekly',
        'period': 'weekly',
        'priceMicros': 100,
        'currencyCode': 'USD',
      }),
      throwsA(isA<ApiMappingException>()),
    );
  });
}
