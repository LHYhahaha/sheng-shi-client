import 'dart:async';

import 'package:drama_client/app/app_root_navigator_key.dart';
import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/bootstrap/app_modal_registry_bootstrap.dart';
import 'package:drama_client/core/modal/app_modal_host.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/domain/delete_account_result.dart';
import 'package:drama_client/features/auth/presentation/pages/account_page.dart';
import 'package:drama_client/features/auth/presentation/pages/auth_page.dart';
import 'package:drama_client/features/profile/presentation/pages/profile_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('auth page shows initial loading while session loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRouterApp(
        initialLocation: RoutePaths.auth,
        repository: _BlockingFetchAuthRepository(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue with Device'), findsNothing);
  });

  testWidgets('auth load failure keeps login actions available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildRouterApp(
        initialLocation: RoutePaths.auth,
        repository: _WidgetAuthRepository(failFetch: true),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Login failed. Please try again.'), findsOneWidget);
    expect(find.text('Continue with Device'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
  });

  testWidgets('login failure clears pending state and can retry', (
    tester,
  ) async {
    final repository = _WidgetAuthRepository(failLogin: true);

    await tester.pumpWidget(
      _buildRouterApp(initialLocation: RoutePaths.auth, repository: repository),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Login failed. Please try again.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);

    repository.failLogin = false;
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Google User'), findsOneWidget);
    expect(find.text('Log in >'), findsNothing);
  });

  testWidgets('profile shows login during auth loading and user after login', (
    tester,
  ) async {
    final repository = _WidgetAuthRepository();

    await tester.pumpWidget(
      _buildRouterApp(
        initialLocation: RoutePaths.profile,
        repository: repository,
      ),
    );
    await tester.pump();

    expect(find.text('Log in >'), findsOneWidget);

    await tester.tap(find.text('Log in >'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Google User'), findsOneWidget);
    expect(find.text('Log in >'), findsNothing);
  });

  testWidgets('account logout failure stays retryable then returns profile', (
    tester,
  ) async {
    final repository = _WidgetAuthRepository.signedIn(failLogout: true);

    await tester.pumpWidget(
      _buildRouterApp(
        initialLocation: RoutePaths.account,
        repository: repository,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Logout failed. Please try again.'), findsOneWidget);
    expect(find.text('Google User'), findsOneWidget);

    repository.failLogout = false;
    await tester.tap(find.text('Log out'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Log in >'), findsOneWidget);
  });

  testWidgets('account delete failure stays retryable then returns profile', (
    tester,
  ) async {
    final repository = _WidgetAuthRepository.signedIn(failDelete: true);

    await tester.pumpWidget(
      _buildRouterApp(
        initialLocation: RoutePaths.account,
        repository: repository,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(
      find.text('Delete account failed. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Google User'), findsOneWidget);

    repository.failDelete = false;
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Log in >'), findsOneWidget);
  });

  testWidgets('account actions are disabled while logout is pending', (
    tester,
  ) async {
    final repository = _BlockingLogoutAuthRepository();

    await tester.pumpWidget(
      _buildRouterApp(
        initialLocation: RoutePaths.account,
        repository: repository,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pump();
    expect(
      find.text('This is a mock delete account confirmation for MVP testing.'),
      findsNothing,
    );

    repository.completeLogout();
    await tester.pumpAndSettle();
    expect(find.text('Log in >'), findsOneWidget);
  });
}

Widget _buildRouterApp({
  required String initialLocation,
  required AuthRepository repository,
}) {
  final router = GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: RoutePaths.account,
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfilePage(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      ...appModalRegistryOverrides,
    ],
    child: MaterialApp.router(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) =>
          AppModalHost(child: child ?? const SizedBox.shrink()),
    ),
  );
}

class _WidgetAuthRepository implements AuthRepository {
  _WidgetAuthRepository({
    this.failFetch = false,
    this.failLogin = false,
    this.failLogout = false,
    this.failDelete = false,
    AuthSession session = const AuthSession.guest(),
  }) : _session = session;

  factory _WidgetAuthRepository.signedIn({
    bool failLogout = false,
    bool failDelete = false,
  }) {
    return _WidgetAuthRepository(
      failLogout: failLogout,
      failDelete: failDelete,
      session: _sessionFor(AuthProviderType.google),
    );
  }

  bool failFetch;
  bool failLogin;
  bool failLogout;
  bool failDelete;
  AuthSession _session;

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    if (failLogin) {
      throw StateError('login failed');
    }
    _session = _sessionFor(provider);
    return _session;
  }

  @override
  Future<AuthSession> logout() async {
    if (failLogout) {
      throw StateError('logout failed');
    }
    _session = const AuthSession.guest();
    return _session;
  }

  @override
  Future<DeleteAccountResult> deleteAccount() async {
    if (failDelete) {
      throw StateError('delete failed');
    }
    _session = const AuthSession.guest();
    return DeleteAccountResult(session: _session, shouldExitApp: true);
  }
}

class _BlockingFetchAuthRepository extends _WidgetAuthRepository {
  final Completer<AuthSession> _fetchCompleter = Completer<AuthSession>();
}

class _BlockingLogoutAuthRepository extends _WidgetAuthRepository {
  _BlockingLogoutAuthRepository()
    : super(session: _sessionFor(AuthProviderType.google));

  final Completer<AuthSession> _logoutCompleter = Completer<AuthSession>();

  @override
  Future<AuthSession> logout() => _logoutCompleter.future;

  void completeLogout() {
    _logoutCompleter.complete(const AuthSession.guest());
  }
}

AuthSession _sessionFor(AuthProviderType provider) {
  return AuthSession(
    user: AuthUser(
      id: '15589299',
      nickname: switch (provider) {
        AuthProviderType.device => 'Device User',
        AuthProviderType.phone => 'Phone User',
        AuthProviderType.google => 'Google User',
        AuthProviderType.facebook => 'Facebook User',
      },
      avatarAssetPath: authDefaultAvatarAssetPath,
      provider: provider,
    ),
  );
}
