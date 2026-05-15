class AuthTokenDto {
  const AuthTokenDto({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    this.expiresAt,
    this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime? expiresAt;
  final DateTime? refreshExpiresAt;

  factory AuthTokenDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return AuthTokenDto(
      accessToken: _string(map['accessToken']),
      refreshToken: _string(map['refreshToken']),
      tokenType: _string(map['tokenType'], fallback: 'Bearer'),
      expiresAt: _date(map['expiresAt']),
      refreshExpiresAt: _date(map['refreshExpiresAt']),
    );
  }
}

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
