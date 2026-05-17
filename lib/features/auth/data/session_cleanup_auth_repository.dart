import '../../../core/auth/session_cleanup_coordinator.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';

/// 在 logout/delete 成功后触发统一 session cleanup。
///
/// 放在 auth data 层，避免 AuthController（application）直接依赖 coordinator，同时保证
/// mock 与 remote repository 行为一致。
class SessionCleanupAuthRepository implements AuthRepository {
  SessionCleanupAuthRepository({
    required AuthRepository delegate,
    required SessionCleanupCoordinator sessionCleanup,
  }) : delegate = delegate,
       _sessionCleanup = sessionCleanup;

  final AuthRepository delegate;
  final SessionCleanupCoordinator _sessionCleanup;

  @override
  Future<AuthSession> fetchSession() => delegate.fetchSession();

  @override
  Future<AuthSession> login(AuthProviderType provider) =>
      delegate.login(provider);

  @override
  Future<AuthSession> logout() async {
    final session = await delegate.logout();
    await _sessionCleanup.cleanup(SessionCleanupReason.logout);
    return session;
  }

  @override
  Future<AuthSession> deleteAccount() async {
    final session = await delegate.deleteAccount();
    await _sessionCleanup.cleanup(SessionCleanupReason.deleteAccount);
    return session;
  }
}
