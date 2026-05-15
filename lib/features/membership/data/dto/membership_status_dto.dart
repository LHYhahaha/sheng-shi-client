import 'membership_benefit_dto.dart';

class MembershipStatusDto {
  const MembershipStatusDto({
    required this.isActive,
    this.planId,
    this.expiresAt,
    this.renewsAt,
    required this.autoRenewEnabled,
    this.source,
    required this.benefits,
  });

  final bool isActive;
  final String? planId;
  final DateTime? expiresAt;
  final DateTime? renewsAt;
  final bool autoRenewEnabled;
  final String? source;
  final List<MembershipBenefitDto> benefits;

  factory MembershipStatusDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return MembershipStatusDto(
      isActive: map['isActive'] == true,
      planId: _nullableString(map['planId']),
      expiresAt: _date(map['expiresAt']),
      renewsAt: _date(map['renewsAt']),
      autoRenewEnabled: map['autoRenewEnabled'] == true,
      source: _nullableString(map['source']),
      benefits: _list(map['benefits'], MembershipBenefitDto.fromJson),
    );
  }
}

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

List<T> _list<T>(Object? value, T Function(Object? json) mapper) {
  if (value is List) return value.map(mapper).toList(growable: false);
  return <T>[];
}
