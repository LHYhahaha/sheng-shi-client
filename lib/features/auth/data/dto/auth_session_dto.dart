import 'auth_token_dto.dart';
import 'auth_user_dto.dart';

class AuthSessionDto {
  const AuthSessionDto({
    required this.isAuthenticated,
    this.user,
    this.token,
    this.serverTime,
    required this.isNewUser,
  });

  final bool isAuthenticated;
  final AuthUserDto? user;
  final AuthTokenDto? token;
  final DateTime? serverTime;
  final bool isNewUser;

  factory AuthSessionDto.fromJson(Object? json) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    return AuthSessionDto(
      isAuthenticated: map['isAuthenticated'] == true,
      user: map['user'] == null ? null : AuthUserDto.fromJson(map['user']),
      token: map['token'] == null ? null : AuthTokenDto.fromJson(map['token']),
      serverTime: _date(map['serverTime']),
      isNewUser: map['isNewUser'] == true,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}
