import '../../../../core/network/json_field_parser.dart';

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
  final int priceMicros;
  final String currencyCode;
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
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'StoreRechargeProductDto',
    );
    const dtoName = 'StoreRechargeProductDto';
    return StoreRechargeProductDto(
      productId: JsonFieldParser.requireString(
        map,
        'productId',
        dtoName: dtoName,
      ),
      platformProductId: JsonFieldParser.requireString(
        map,
        'platformProductId',
        dtoName: dtoName,
      ),
      basePlanId: JsonFieldParser.optionalString(map, 'basePlanId'),
      offerId: JsonFieldParser.optionalString(map, 'offerId'),
      productType: JsonFieldParser.optionalString(map, 'productType'),
      kind: JsonFieldParser.optionalString(map, 'kind') ?? 'coins',
      title: JsonFieldParser.optionalString(map, 'title') ?? '',
      baseCoins: JsonFieldParser.requireInt(map, 'baseCoins', dtoName: dtoName),
      bonusCoins: JsonFieldParser.requireInt(
        map,
        'bonusCoins',
        dtoName: dtoName,
      ),
      totalCoins: JsonFieldParser.requireInt(
        map,
        'totalCoins',
        dtoName: dtoName,
      ),
      priceMicros: JsonFieldParser.requireInt(
        map,
        'priceMicros',
        dtoName: dtoName,
      ),
      currencyCode: JsonFieldParser.requireString(
        map,
        'currencyCode',
        dtoName: dtoName,
      ),
      localizedPrice:
          JsonFieldParser.optionalString(map, 'localizedPrice') ?? '',
      originalPriceMicros: JsonFieldParser.optionalInt(
        map,
        'originalPriceMicros',
      ),
      localizedOriginalPrice: JsonFieldParser.optionalString(
        map,
        'localizedOriginalPrice',
      ),
      promotionId: JsonFieldParser.optionalString(map, 'promotionId'),
      promotionExpiresAt: JsonFieldParser.optionalDateTime(
        map,
        'promotionExpiresAt',
      ),
      sortOrder: JsonFieldParser.optionalInt(map, 'sortOrder') ?? 0,
      enabled: JsonFieldParser.requireBool(map, 'enabled', dtoName: dtoName),
      subtitle: JsonFieldParser.optionalString(map, 'subtitle'),
      footnote: JsonFieldParser.optionalString(map, 'footnote'),
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
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'StoreRechargeProductBenefitDto',
    );
    return StoreRechargeProductBenefitDto(
      icon: JsonFieldParser.optionalString(map, 'icon') ?? 'drama',
      label: JsonFieldParser.optionalString(map, 'label') ?? '',
    );
  }
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
