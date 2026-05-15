class StoreRechargeProductDto {
  const StoreRechargeProductDto({
    required this.productId,
    required this.platformProductId,
    this.basePlanId,
    this.offerId,
    this.productType,
    required this.kind,
    required this.title,
    required this.baseCoins,
    required this.bonusCoins,
    required this.totalCoins,
    required this.priceMicros,
    required this.currencyCode,
    required this.localizedPrice,
    required this.originalPriceMicros,
    required this.localizedOriginalPrice,
    required this.promotionId,
    required this.promotionExpiresAt,
    required this.sortOrder,
    required this.enabled,
    required this.subtitle,
    required this.footnote,
    required this.benefits,
  });

  final String productId;
  final String platformProductId;
  final String? basePlanId;
  final String? offerId;
  final String? productType;
  final String kind;
  final String title;
  final int baseCoins;
  final int bonusCoins;
  final int totalCoins;
  final int? priceMicros;
  final String? currencyCode;
  final String localizedPrice;
  final int? originalPriceMicros;
  final String? localizedOriginalPrice;
  final String? promotionId;
  final DateTime? promotionExpiresAt;
  final int sortOrder;
  final bool enabled;
  final String? subtitle;
  final String? footnote;
  final List<StoreRechargeProductBenefitDto> benefits;

  factory StoreRechargeProductDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return StoreRechargeProductDto(
      productId: _string(map['productId']),
      platformProductId: _string(map['platformProductId']),
      basePlanId: _nullableString(map['basePlanId']),
      offerId: _nullableString(map['offerId']),
      productType: _nullableString(map['productType']),
      kind: _string(map['kind'], fallback: 'coins'),
      title: _string(map['title']),
      baseCoins: _int(map['baseCoins']),
      bonusCoins: _int(map['bonusCoins']),
      totalCoins: _int(map['totalCoins']),
      priceMicros: _nullableInt(map['priceMicros']),
      currencyCode: _nullableString(map['currencyCode']),
      localizedPrice: _string(map['localizedPrice']),
      originalPriceMicros: _nullableInt(map['originalPriceMicros']),
      localizedOriginalPrice: _nullableString(map['localizedOriginalPrice']),
      promotionId: _nullableString(map['promotionId']),
      promotionExpiresAt: _date(map['promotionExpiresAt']),
      sortOrder: _int(map['sortOrder']),
      enabled: map['enabled'] != false,
      subtitle: _nullableString(map['subtitle']),
      footnote: _nullableString(map['footnote']),
      benefits: _list(map['benefits'], StoreRechargeProductBenefitDto.fromJson),
    );
  }
}

class StoreRechargeProductBenefitDto {
  const StoreRechargeProductBenefitDto({
    required this.icon,
    required this.label,
  });

  final String icon;
  final String label;

  factory StoreRechargeProductBenefitDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return StoreRechargeProductBenefitDto(
      icon: _string(map['icon'], fallback: 'drama'),
      label: _string(map['label']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
