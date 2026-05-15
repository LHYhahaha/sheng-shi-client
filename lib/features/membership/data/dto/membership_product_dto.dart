import 'membership_benefit_dto.dart';

class MembershipProductDto {
  const MembershipProductDto({
    required this.productId,
    required this.platformProductId,
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
  final String period;
  final String title;
  final int? priceMicros;
  final String? currencyCode;
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
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return MembershipProductDto(
      productId: _string(map['productId']),
      platformProductId: _string(map['platformProductId']),
      period: _string(map['period'], fallback: 'weekly'),
      title: _string(map['title']),
      priceMicros: _nullableInt(map['priceMicros']),
      currencyCode: _nullableString(map['currencyCode']),
      localizedPrice: _string(map['localizedPrice']),
      originalPriceMicros: _nullableInt(map['originalPriceMicros']),
      localizedOriginalPrice: _nullableString(map['localizedOriginalPrice']),
      promotionId: _nullableString(map['promotionId']),
      promotionExpiresAt: _date(map['promotionExpiresAt']),
      benefits: _list(map['benefits'], MembershipBenefitDto.fromJson),
      tips: _stringList(map['tips']),
      enabled: map['enabled'] != false,
      dailyPriceLabel: _nullableString(map['dailyPriceLabel']),
      description: _nullableString(map['description']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

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

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}
