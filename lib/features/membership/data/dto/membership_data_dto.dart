import 'membership_benefit_dto.dart';
import 'membership_product_dto.dart';
import 'membership_status_dto.dart';

class MembershipDataDto {
  const MembershipDataDto({
    required this.status,
    required this.products,
    required this.benefits,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.subscriptionNote,
    required this.tips,
  });

  final MembershipStatusDto? status;
  final List<MembershipProductDto> products;
  final List<MembershipBenefitDto> benefits;
  final String heroTitle;
  final String heroSubtitle;
  final String subscriptionNote;
  final List<String> tips;

  factory MembershipDataDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return MembershipDataDto(
      status: map['status'] == null
          ? null
          : MembershipStatusDto.fromJson(map['status']),
      products: _list(map['products'], MembershipProductDto.fromJson),
      benefits: _list(map['benefits'], MembershipBenefitDto.fromJson),
      heroTitle: _string(map['heroTitle'], fallback: 'Join Membership'),
      heroSubtitle: _string(map['heroSubtitle']),
      subscriptionNote: _string(map['subscriptionNote']),
      tips: _stringList(map['tips']),
    );
  }
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
