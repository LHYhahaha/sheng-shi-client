import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

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
