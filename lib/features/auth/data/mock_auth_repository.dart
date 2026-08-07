import '../domain/account_deletion_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/delete_account_result.dart';

/// Auth mock 仓库。
///
/// 用延迟模拟平台登录/账号操作，但不持久化真实凭证。真实接入时仍应保持相同接口，
/// 让 AuthController 继续负责 pending/error/session 合成。
class MockAuthRepository
    implements AuthRepository, CurrentAuthSessionSynchronizer {
  MockAuthRepository();

  AuthSession _session = const AuthSession.guest(
    sessionId: 'guest-sess-mock',
    guestId: 'guest-mock',
  );

  /// 测试用：模拟服务端拒绝注销（余额不为 0 / 仍为会员等）。
  AccountDeletionRejectedException? forcedDeleteRejection;

  /// 测试用：模拟注销接口返回的 shouldExitApp 值。
  ///
  /// 默认值为 true，模拟游客或当前设备账号注销后退出App的场景。
  /// 测试三方登录注销场景时可设置为 false。
  bool mockDeleteAccountShouldExitApp = true;

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final linkGuestId = _session.guestId ?? _session.sessionId;
    _session = AuthSession(
      user: AuthUser(
        userId: '15589299',
        nickname: switch (provider) {
          AuthProviderType.device => 'Device User',
          AuthProviderType.google => 'Google User',
          AuthProviderType.facebook => 'Facebook User',
        },
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
      ),
      sessionId: 'sess-${provider.name}',
      guestId: linkGuestId,
    );
    return _session;
  }

  @override
  Future<AuthSession> syncCurrentSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _session;
  }

  @override
  Future<AuthSession> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _session = const AuthSession.guest(
      sessionId: 'guest-sess-mock',
      guestId: 'guest-mock',
    );
    return _session;
  }

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final rejection = forcedDeleteRejection;
    if (rejection != null) {
      throw rejection;
    }
    _session = const AuthSession.guest(
      sessionId: 'guest-sess-mock',
      guestId: 'guest-mock',
    );
    return DeleteAccountResult(
      session: _session,
      shouldExitApp: mockDeleteAccountShouldExitApp,
    );
  }
}
