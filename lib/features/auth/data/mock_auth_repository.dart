import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// Auth mock 仓库。
///
/// 用延迟模拟平台登录/账号操作，但不持久化真实凭证。真实接入时仍应保持相同接口，
/// 让 AuthController 继续负责 pending/error/session 合成。
class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  AuthSession _session = const AuthSession.guest();

  @override
  Future<AuthSession> fetchSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return _session;
  }

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _session = AuthSession(
      user: AuthUser(
        id: '15589299',
        nickname: switch (provider) {
          AuthProviderType.device => 'Device User',
          AuthProviderType.google => 'Google User',
          AuthProviderType.facebook => 'Facebook User',
        },
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
      ),
    );
    return _session;
  }

  @override
  Future<AuthSession> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _session = const AuthSession.guest();
    return _session;
  }

  @override
  Future<AuthSession> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _session = const AuthSession.guest();
    return _session;
  }
}
