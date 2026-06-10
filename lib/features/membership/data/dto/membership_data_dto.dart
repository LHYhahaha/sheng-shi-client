import 'membership_product_dto.dart';

class MembershipDataDto {
  const MembershipDataDto({
    required this.isMember,
    required this.memberProducts,
    required this.vipExpireAt,
    required this.heroTitle,
    required this.heroSubtitle,
  });

  final bool isMember;
  final List<MembershipProductDto> memberProducts;
  final String? vipExpireAt;
  final String heroTitle;
  final String heroSubtitle;

  factory MembershipDataDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};

    return MembershipDataDto(
      isMember: map['isMember'] == true,
      memberProducts: _list(
        map['memberProducts'],
        MembershipProductDto.fromJson,
      ),
      vipExpireAt: _nullableString(map['vipExpireAt']),
      heroTitle: _string(map['heroTitle'], fallback: 'Join Membership'),
      heroSubtitle: _string(map['heroSubtitle']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
