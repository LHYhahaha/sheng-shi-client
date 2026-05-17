import '../../../../core/network/json_field_parser.dart';
import 'membership_benefit_dto.dart';

class MembershipProductDto {
  const MembershipProductDto({
    required this.productId,
    required this.platformProductId,
    this.basePlanId,
    this.offerId,
    this.productType,
    required this.period,
    required this.title,
    required this.priceMicros,
    required this.currencyCode,
    required this.localizedPrice,
    required this.originalPriceMicros,
    required this.localizedOriginalPrice,
    required this.promotionId,
    required this.promotionExpiresAt,
    required this.benefits,
    required this.tips,
    required this.enabled,
    this.dailyPriceLabel,
    this.description,
  });

  final String productId;
  final String platformProductId;
  final String? basePlanId;
  final String? offerId;
  final String? productType;
  final String period;
  final String title;
  final int priceMicros;
  final String currencyCode;
  final String localizedPrice;
  final int? originalPriceMicros;
  final String? localizedOriginalPrice;
  final String? promotionId;
  final DateTime? promotionExpiresAt;
  final List<MembershipBenefitDto> benefits;
  final List<String> tips;
  final bool enabled;
  final String? dailyPriceLabel;
  final String? description;

  factory MembershipProductDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(
      json,
      dtoName: 'MembershipProductDto',
    );
    const dtoName = 'MembershipProductDto';
    return MembershipProductDto(
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
      period: JsonFieldParser.requireString(map, 'period', dtoName: dtoName),
      title: JsonFieldParser.optionalString(map, 'title') ?? '',
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
      benefits: _list(map['benefits'], MembershipBenefitDto.fromJson),
      tips: _stringList(map['tips']),
      enabled: JsonFieldParser.requireBool(map, 'enabled', dtoName: dtoName),
      dailyPriceLabel: JsonFieldParser.optionalString(map, 'dailyPriceLabel'),
      description: JsonFieldParser.optionalString(map, 'description'),
    );
  }
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}
