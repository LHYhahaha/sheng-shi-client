import '../../../../core/network/json_field_parser.dart';

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
    final map = JsonFieldParser.requireMap(json, dtoName: 'AuthUserDto');
    return AuthUserDto(
      userId: JsonFieldParser.requireString(
        map,
        'userId',
        dtoName: 'AuthUserDto',
      ),
      nickname: JsonFieldParser.optionalString(map, 'nickname') ?? '',
      avatarUrl: JsonFieldParser.optionalString(map, 'avatarUrl'),
      provider: JsonFieldParser.optionalString(map, 'provider') ?? 'device',
      isGuest: JsonFieldParser.requireBool(
        map,
        'isGuest',
        dtoName: 'AuthUserDto',
      ),
      createdAt: JsonFieldParser.optionalDateTime(map, 'createdAt'),
    );
  }
}
