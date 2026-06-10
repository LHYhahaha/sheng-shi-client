import 'coin_product_dto.dart';
import 'member_product_dto.dart';

/// 充值页数据DTO
///
/// 对应 API `/api/payment/recharge/page` 返回的 `data` 字段。
class StoreRechargeDataDto {
  const StoreRechargeDataDto({
    required this.coin,
    required this.bonusCoin,
    required this.coinProducts,
    required this.memberProducts,
    required this.requiredCoin,
  });

  final String coin;
  final String bonusCoin;
  final List<CoinProductDto> coinProducts;
  final List<MemberProductDto> memberProducts;
  final String requiredCoin;

  /// 当前金币余额（从 [coin] 解析）
  int get balance {
    final value = int.tryParse(coin);
    return value ?? 0;
  }

  factory StoreRechargeDataDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return StoreRechargeDataDto(
      coin: _string(map['coin']),
      bonusCoin: _string(map['bonusCoin']),
      coinProducts: _list(map['coinProducts'], CoinProductDto.fromJson),
      memberProducts: _list(map['memberProducts'], MemberProductDto.fromJson),
      requiredCoin: _string(map['requiredCoin']),
    );
  }
}

String _string(Object? value, {String fallback = '0'}) =>
    value is String ? value : fallback;

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
