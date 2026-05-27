import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_modal_test_harness.dart';

void main() {
  testWidgets('profile login modal cancel keeps guest session', (tester) async {
    await tester.pumpWidget(
      buildAppModalTestApp(
        home: const ProfilePage(),
        overrides: [
          authRepositoryProvider.overrideWithValue(_GuestAuthRepository()),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Log in >'), findsOneWidget);

    await tester.tap(find.text('Log in >'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Google'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Log in >'), findsOneWidget);
  });

  testWidgets('profile google login via modal authenticates user', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildAppModalTestApp(
        home: const ProfilePage(),
        overrides: [
          authRepositoryProvider.overrideWithValue(_GuestAuthRepository()),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in >'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Google User'), findsOneWidget);
    expect(find.text('Log in >'), findsNothing);
  });
}

class _GuestAuthRepository implements AuthRepository {
  AuthSession _session = const AuthSession.guest(
    sessionId: 'guest-sess',
    guestId: 'guest-1',
  );

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    final guestId = _session.guestId;
    _session = AuthSession(
      user: AuthUser(
        id: '15589299',
        nickname: 'Google User',
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
      ),
      guestId: guestId,
    );
    return _session;
  }

  @override
  Future<AuthSession> logout() async {
    _session = const AuthSession.guest();
    return _session;
  }

  @override
  Future<AuthSession> deleteAccount() async {
    _session = const AuthSession.guest();
    return _session;
  }
}
