import '../../features/auth/domain/auth_session.dart';
import 'user_info_store.dart';

/// 用户信息管理器
///
/// 统一管理用户信息的构建和转换，避免在多个地方重复实现相同逻辑。
/// 这是一个纯函数类，不依赖任何外部状态。
class UserInfoManager {
  /// 从已保存的用户信息构建 AuthSession
  ///
  /// 如果有完整的用户信息（userId 和 nickname），返回 authenticated session；
  /// 否则返回 guest session。
  ///
  /// 参数：
  ///   - userInfo: 用户信息快照
  ///   - provider: 登录渠道（默认为 device）
  ///
  /// 返回：
  ///   - AuthSession: 认证会话（authenticated 或 guest）
  static AuthSession buildSessionFromUserInfo(
    UserInfoSnapshot userInfo, {
    AuthProviderType provider = AuthProviderType.device,
  }) {
    if (userInfo.hasUserInfo &&
        userInfo.userId != null &&
        userInfo.nickname != null) {
      print(
        '[UserInfoManager] Building authenticated session for user: ${userInfo.userId}',
      );

      final user = AuthUser(
        id: userInfo.userId.toString(),
        nickname: userInfo.nickname ?? '',
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
        showId: userInfo.showId,
        language: userInfo.language,
        status: userInfo.status,
        vipExpireAt: userInfo.vipExpireAt,
        coin: userInfo.coin,
        bonusCoin: userInfo.bonusCoin,
        autoUnlock: userInfo.autoUnlock,
      );

      return AuthSession(user: user);
    }

    print(
      '[UserInfoManager] No user info available, returning guest session',
    );
    return const AuthSession.guest();
  }
}
