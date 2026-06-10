

class MembershipStatusDto {
  const MembershipStatusDto({
    required this.isActive,
    this.planId,
    this.expiresAt,
    this.renewsAt,
    required this.autoRenewEnabled,
    this.source,
  });

  final bool isActive;
  final String? planId;
  final DateTime? expiresAt;
  final DateTime? renewsAt;
  final bool autoRenewEnabled;
  final String? source;


  factory MembershipStatusDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return MembershipStatusDto(
      isActive: map['isActive'] == true,
      planId: _nullableString(map['planId']),
      expiresAt: _date(map['expiresAt']),
      renewsAt: _date(map['renewsAt']),
      autoRenewEnabled: map['autoRenewEnabled'] == true,
      source: _nullableString(map['source']),
    );
  }
}

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}


