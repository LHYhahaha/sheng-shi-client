import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';
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
    final map = JsonFieldParser.requireMap(json, dtoName: 'AuthSessionDto');
    final isAuthenticated = JsonFieldParser.requireBool(
      map,
      'isAuthenticated',
      dtoName: 'AuthSessionDto',
    );
    final user = map['user'] == null ? null : AuthUserDto.fromJson(map['user']);
    final token = map['token'] == null
        ? null
        : AuthTokenDto.fromJson(map['token']);

    if (isAuthenticated && token == null) {
      throw const ApiMappingException(
        dtoName: 'AuthSessionDto',
        field: 'token',
        reason: 'authenticated session requires token',
      );
    }
    if (isAuthenticated &&
        user != null &&
        !user.isGuest &&
        user.userId.isEmpty) {
      throw const ApiMappingException(
        dtoName: 'AuthSessionDto',
        field: 'user.userId',
        reason: 'authenticated user requires userId',
      );
    }

    return AuthSessionDto(
      isAuthenticated: isAuthenticated,
      user: user,
      token: token,
      serverTime: JsonFieldParser.optionalDateTime(map, 'serverTime'),
      isNewUser: JsonFieldParser.requireBool(
        map,
        'isNewUser',
        dtoName: 'AuthSessionDto',
      ),
    );
  }
}
