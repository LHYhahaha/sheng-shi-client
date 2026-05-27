import 'auth_session.dart';

/// 认证仓库边界。
///
/// 平台登录、token 刷新、logout 和 delete account 都应收敛在这里，UI 只处理状态和
/// 导航。这样失败时才能统一保留旧 session 或切回 guest。
abstract interface class AuthRepository {
  Future<AuthSession> login(AuthProviderType provider);

  Future<AuthSession> logout();

  Future<AuthSession> deleteAccount();
}
