import 'store_recharge_product_dto.dart';

class StoreRechargeDataDto {
  const StoreRechargeDataDto({
    required this.balance,
    required this.coinProducts,
    required this.vipProducts,
    required this.tips,
    required this.linksLabel,
    required this.subscriptionNote,
  });

  final int balance;
  final List<StoreRechargeProductDto> coinProducts;
  final List<StoreRechargeProductDto> vipProducts;
  final List<String> tips;
  final String linksLabel;
  final String subscriptionNote;

  factory StoreRechargeDataDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return StoreRechargeDataDto(
      balance: _int(map['balance']),
      coinProducts: _list(
        map['coinProducts'],
        StoreRechargeProductDto.fromJson,
      ),
      vipProducts: _list(map['vipProducts'], StoreRechargeProductDto.fromJson),
      tips: _stringList(map['tips']),
      linksLabel: _string(map['linksLabel']),
      subscriptionNote: _string(map['subscriptionNote']),
    );
  }
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
