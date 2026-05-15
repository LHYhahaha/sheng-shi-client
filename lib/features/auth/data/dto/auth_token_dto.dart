/// 远程 token 契约 DTO。
///
/// token 只允许停留在 data/core session 边界。不要把这个 DTO 或字段映射进
/// presentation 可见的 AuthSession；真实阶段应由 secure storage + ApiRequestContext
/// provider 负责读取、刷新和清理。
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
