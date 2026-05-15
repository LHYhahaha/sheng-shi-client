class MembershipBenefitDto {
  const MembershipBenefitDto({
    required this.icon,
    required this.title,
    this.highlight,
    this.description,
  });

  final String icon;
  final String title;
  final String? highlight;
  final String? description;

  factory MembershipBenefitDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return MembershipBenefitDto(
      icon: _string(map['icon'], fallback: 'series'),
      title: _string(map['title']),
      highlight: _nullableString(map['highlight']),
      description: _nullableString(map['description']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
