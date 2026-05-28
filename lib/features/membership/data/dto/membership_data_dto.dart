import 'membership_benefit_dto.dart';
import 'membership_product_dto.dart';

class MembershipDataDto {
  const MembershipDataDto({
    required this.isMember,
    required this.memberProducts,
    required this.vipExpireAt,
    required this.userId,
    required this.benefits,
    required this.heroTitle,
    required this.heroSubtitle,
    required this.subscriptionNote,
    required this.tips,
  });

  final bool isMember;
  final List<MembershipProductDto> memberProducts;
  final String? vipExpireAt;
  final int userId;
  final List<MembershipBenefitDto> benefits;
  final String heroTitle;
  final String heroSubtitle;
  final String subscriptionNote;
  final List<String> tips;

  factory MembershipDataDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final data = map['data'] is Map<String, Object?> ? map['data'] as Map<String, Object?> : const <String, Object?>{};
    
    return MembershipDataDto(
      isMember: data['isMember'] == true,
      memberProducts: _list(data['memberProducts'], MembershipProductDto.fromJson),
      vipExpireAt: _nullableString(data['vipExpireAt']),
      userId: _int(data['userId']),
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

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

int _int(Object? value) =>
    value is int ? value : 0;

List<String> _stringList(Object? value) {
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const <String>[];
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
