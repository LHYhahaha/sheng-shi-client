import '../../../../shared/media/media_resource.dart';
import '../../domain/auth_session.dart';
import '../dto/auth_session_dto.dart';
import '../dto/auth_user_dto.dart';

/// Auth DTO 到 domain 的 mapper。
///
/// token 只留在 data/core 边界，不能映射进 AuthSession 暴露给 UI。真实 token storage
/// 和 refresh queue 后续接入时，也应替换网络上下文 provider，而不是让页面接触 token。
class AuthMapper {
  const AuthMapper();

  AuthSession mapSession(AuthSessionDto dto) {
    if (!dto.isAuthenticated || dto.user == null || dto.user!.isGuest) {
      return AuthSession.guest(sessionId: dto.sessionId, guestId: dto.guestId);
    }
    return AuthSession(
      user: mapUser(dto.user!),
      sessionId: dto.sessionId,
      guestId: dto.guestId,
    );
  }

  AuthUser mapUser(AuthUserDto dto) {
    return AuthUser(
      userId: dto.userId,
      nickname: dto.nickname,
      avatarAssetPath: authDefaultAvatarAssetPath,
      avatarResource: dto.avatarUrl == null
          ? const MediaResource.asset(authDefaultAvatarAssetPath)
          : MediaResource.network(dto.avatarUrl!),
      provider: _provider(dto.provider),
    );
  }

  AuthProviderType _provider(String value) {
    switch (value.toLowerCase()) {
      case 'google':
        return AuthProviderType.google;
      case 'facebook':
        return AuthProviderType.facebook;
      case 'phone':
        return AuthProviderType.phone;
      case 'device':
      default:
        return AuthProviderType.device;
    }
  }
}
