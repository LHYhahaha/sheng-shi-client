import '../../../../core/network/json_field_parser.dart';

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
    final map = JsonFieldParser.requireMap(json, dtoName: 'AuthTokenDto');
    return AuthTokenDto(
      accessToken: JsonFieldParser.requireString(
        map,
        'accessToken',
        dtoName: 'AuthTokenDto',
      ),
      refreshToken: JsonFieldParser.requireString(
        map,
        'refreshToken',
        dtoName: 'AuthTokenDto',
      ),
      tokenType: JsonFieldParser.optionalString(map, 'tokenType') ?? 'Bearer',
      expiresAt: JsonFieldParser.optionalDateTime(map, 'expiresAt'),
      refreshExpiresAt: JsonFieldParser.optionalDateTime(
        map,
        'refreshExpiresAt',
      ),
    );
  }
}
