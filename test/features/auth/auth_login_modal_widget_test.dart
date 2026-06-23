import 'package:drama_client/core/runtime/install_id_provider.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/domain/delete_account_result.dart';
import 'package:drama_client/features/auth/presentation/pages/auth_page.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/profile/presentation/pages/profile_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('profile login page back keeps guest session', (tester) async {
    await tester.pumpWidget(
      _buildRoutedAuthTestApp(
        authRepository: _GuestAuthRepository(),
      ),
    );
    await tester.pump();

    expect(find.text('Log in'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Facebook'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth_back_button')));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('profile facebook login via page authenticates user', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRoutedAuthTestApp(
        authRepository: _GuestAuthRepository(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Facebook'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Facebook User'), findsWidgets);
    expect(find.text('Log in'), findsNothing);
    expect(find.text('Sign in with Facebook'), findsNothing);
  });
}

Widget _buildRoutedAuthTestApp({required AuthRepository authRepository}) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      installIdProvider.overrideWith((ref) async => 'test-install-id'),
      entitlementRepositoryProvider.overrideWithValue(
        MockEntitlementRepository.guest(),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
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
        nickname: 'Facebook User',
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
  Future<DeleteAccountResult> deleteAccount() async {
    _session = const AuthSession.guest();
    return DeleteAccountResult(
      session: _session,
      shouldExitApp: true,
    );
  }
}
