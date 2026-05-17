import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest session is not logged in but is a valid session kind', () {
    const session = AuthSession.guest(
      sessionId: 'sess-guest-1',
      guestId: 'guest-99',
    );

    expect(session.isGuest, isTrue);
    expect(session.isLoggedIn, isFalse);
    expect(session.user, isNull);
    expect(session.sessionId, 'sess-guest-1');
    expect(session.guestId, 'guest-99');
  });

  test('authenticated session exposes user without token fields', () {
    const session = AuthSession(
      user: AuthUser(
        id: 'user-1',
        nickname: 'Test',
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: AuthProviderType.google,
      ),
      sessionId: 'sess-auth-1',
      guestId: 'guest-99',
    );

    expect(session.isLoggedIn, isTrue);
    expect(session.kind, AuthSessionKind.authenticated);
    expect(session.user!.id, 'user-1');
    // AuthSession 不承载 refreshToken / accessToken。
    expect(
      () => (session as dynamic).refreshToken,
      throwsA(isA<NoSuchMethodError>()),
    );
  });

  test('recovering session is transitional guest-like state', () {
    const session = AuthSession.recovering(sessionId: 'sess-recovering');

    expect(session.isRecovering, isTrue);
    expect(session.isLoggedIn, isFalse);
    expect(session.isGuest, isFalse);
  });
}
