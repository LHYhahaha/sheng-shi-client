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
    this.sessionId,
    this.guestId,
  });

  final bool isAuthenticated;
  final AuthUserDto? user;
  final AuthTokenDto? token;
  final DateTime? serverTime;
  final bool isNewUser;
  final String? sessionId;
  final String? guestId;

  factory AuthSessionDto.fromJson(Object? json) {
    final map = JsonFieldParser.requireMap(json, dtoName: 'AuthSessionDto');
    
    // 尝试从嵌套的 token 对象中获取（旧格式/mock 格式）
    AuthTokenDto? token;
    if (map['token'] != null) {
      token = AuthTokenDto.fromJson(map['token']);
    }
    
    // 尝试从顶层直接获取 token 字段（新 API 格式）
    if (token == null) {
      final accessToken = JsonFieldParser.optionalString(map, 'accessToken');
      final refreshToken = JsonFieldParser.optionalString(map, 'refreshToken');
      
      if (accessToken != null && refreshToken != null) {
        // 从 Unix 时间戳（秒）转换为 DateTime
        DateTime? expiresAt;
        final accessExpireAt = JsonFieldParser.optionalInt(map, 'accessExpireAt');
        if (accessExpireAt != null) {
          expiresAt = DateTime.fromMillisecondsSinceEpoch(accessExpireAt * 1000);
        }
        
        DateTime? refreshExpiresAt;
        final refreshExpireAt = JsonFieldParser.optionalInt(map, 'refreshExpireAt');
        if (refreshExpireAt != null) {
          refreshExpiresAt = DateTime.fromMillisecondsSinceEpoch(refreshExpireAt * 1000);
        }
        
        token = AuthTokenDto(
          accessToken: accessToken,
          refreshToken: refreshToken,
          tokenType: 'Bearer',
          expiresAt: expiresAt,
          refreshExpiresAt: refreshExpiresAt,
        );
      }
    }
    
    // 获取 isAuthenticated 和 isNewUser，如果不存在则使用默认值
    final isAuthenticatedValue = map['isAuthenticated'];
    final isAuthenticated = _parseBool(isAuthenticatedValue) ?? (token != null);
    
    final isNewUserValue = map['isNewUser'];
    final isNewUser = _parseBool(isNewUserValue) ?? false;
    
    final user = map['user'] == null ? null : AuthUserDto.fromJson(map['user']);

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
      isNewUser: isNewUser,
      sessionId: JsonFieldParser.optionalString(map, 'sessionId'),
      guestId: JsonFieldParser.optionalString(map, 'guestId'),
    );
  }
  
  static bool? _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return switch (value.toLowerCase()) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => null,
      };
    }
    return null;
  }
}
