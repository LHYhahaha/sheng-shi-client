class AuthUserDto {
  const AuthUserDto({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.provider,
    required this.isGuest,
    this.createdAt,
  });

  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String provider;
  final bool isGuest;
  final DateTime? createdAt;

  factory AuthUserDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return AuthUserDto(
      userId: _string(map['userId']),
      nickname: _string(map['nickname']),
      avatarUrl: _nullableString(map['avatarUrl']),
      provider: _string(map['provider'], fallback: 'device'),
      isGuest: map['isGuest'] == true,
      createdAt: _date(map['createdAt']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

String? _nullableString(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
