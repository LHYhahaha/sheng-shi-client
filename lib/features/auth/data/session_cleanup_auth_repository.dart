import '../../../core/auth/session_cleanup_coordinator.dart';
import '../../../core/auth/user_info_store.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/delete_account_result.dart';

/// 在 logout/delete 成功后触发统一 session cleanup。
///
/// 放在 auth data 层，避免 AuthController（application）直接依赖 coordinator，同时保证
/// mock 与 remote repository 行为一致。
class SessionCleanupAuthRepository
    implements AuthRepository, CurrentAuthSessionSynchronizer {
  SessionCleanupAuthRepository({
    required this.delegate,
    required SessionCleanupCoordinator sessionCleanup,
    UserInfoStore? userInfoStore,
  }) : _sessionCleanup = sessionCleanup,
       _userInfoStore = userInfoStore;

  final AuthRepository delegate;
  final SessionCleanupCoordinator _sessionCleanup;
  final UserInfoStore? _userInfoStore;

  @override
  Future<AuthSession> login(AuthProviderType provider) =>
      delegate.login(provider);

  @override
  Future<AuthSession> syncCurrentSession() {
    if (delegate is CurrentAuthSessionSynchronizer) {
      return (delegate as CurrentAuthSessionSynchronizer).syncCurrentSession();
    }
    return Future.value(const AuthSession.guest());
  }

  @override
  Future<AuthSession> logout() async {
    final session = await delegate.logout();
    await _userInfoStore?.clear();
    await _sessionCleanup.cleanup(SessionCleanupReason.logout);
    return session;
  }

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    final result = await delegate.deleteAccount();
    await _userInfoStore?.clear();
    await _sessionCleanup.cleanup(SessionCleanupReason.deleteAccount);
    return result;
  }
}
