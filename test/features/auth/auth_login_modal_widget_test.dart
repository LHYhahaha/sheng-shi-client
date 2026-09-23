import 'package:drama_client/core/runtime/install_id_provider.dart';
import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_definition.dart';
import 'package:drama_client/core/analytics/analytics_provider.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/core/oauth/oauth_service.dart';
import 'package:drama_client/core/oauth/oauth_service_provider.dart';
import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:drama_client/core/toast/app_toast_service.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/application/facebook_login_config_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/domain/delete_account_result.dart';
import 'package:drama_client/features/auth/presentation/pages/auth_page.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:drama_client/features/entitlement/data/mock_entitlement_repository.dart';
import 'package:drama_client/features/profile/presentation/pages/profile_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../core/toast/recording_app_toast_service.dart';

void main() {
  testWidgets('profile login page back keeps guest session', (tester) async {
    await tester.pumpWidget(
      _buildRoutedAuthTestApp(authRepository: _GuestAuthRepository()),
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
      _buildRoutedAuthTestApp(authRepository: _GuestAuthRepository()),
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

  testWidgets('iOS Apple button starts Apple repository login', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final authRepository = _GuestAuthRepository();
    final toast = RecordingAppToastService();

    await tester.pumpWidget(
      _buildRoutedAuthTestApp(
        authRepository: authRepository,
        initialLocation: '/auth',
        loginConfig: const LoginConfig(
          facebookVisible: true,
          phoneVisible: false,
        ),
        toast: toast,
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('auth_google_button')), findsNothing);
    expect(find.byKey(const ValueKey('auth_apple_button')), findsWidgets);

    expect(authRepository.lastLoginProvider, isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android shows Google login and hides Apple login', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      _buildRoutedAuthTestApp(
        authRepository: _GuestAuthRepository(),
        initialLocation: '/auth',
        loginConfig: const LoginConfig(
          facebookVisible: true,
          phoneVisible: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('auth_google_button')), findsWidgets);
    expect(find.byKey(const ValueKey('auth_apple_button')), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('reports a visible phone login entry once per login page visit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sink = AnalyticsInMemoryEventSink();
    final analytics = AnalyticsService(
      contextReader: () => const AnalyticsContext(
        platform: 'ios',
        appVersion: '1.0.4',
        language: 'en',
      ),
      eventSink: sink,
    );

    await tester.pumpWidget(
      _buildRoutedAuthTestApp(
        authRepository: _GuestAuthRepository(),
        initialLocation: '/auth',
        loginConfig: const LoginConfig(
          facebookVisible: false,
          phoneVisible: true,
        ),
        analytics: analytics,
      ),
    );
    await tester.pump();
    await tester.pump();

      expect(find.byKey(const ValueKey('auth_phone_button')), findsWidgets);
    expect(
      sink.events
          .where(
            (event) =>
                event.eventName == AnalyticsDefinitions.phoneLoginEntryExposure,
          )
          .length,
      1,
    );

    await tester.pump();
    expect(
      sink.events
          .where(
            (event) =>
                event.eventName == AnalyticsDefinitions.phoneLoginEntryExposure,
          )
          .length,
      1,
    );
  });

  testWidgets('login logo scales on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildRoutedAuthTestApp(
        authRepository: _GuestAuthRepository(),
        initialLocation: '/auth',
        loginConfig: const LoginConfig(
          facebookVisible: true,
          phoneVisible: false,
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('auth_login_logo'))).width,
      closeTo(62 * 320 / 375, .01),
    );
  });
}

Widget _buildRoutedAuthTestApp({
  required AuthRepository authRepository,
  OAuthService? oauthService,
  String initialLocation = '/profile',
  LoginConfig? loginConfig,
  AnalyticsService? analytics,
  AppToastService? toast,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
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
      if (loginConfig != null)
        loginConfigProvider.overrideWith((ref) async => loginConfig),
      if (oauthService != null)
        facebookOAuthServiceProvider.overrideWithValue(oauthService),
      if (toast != null) appToastProvider.overrideWithValue(toast),
      if (analytics != null)
        analyticsServiceProvider.overrideWithValue(analytics),
      facebookLoginEnabledProvider.overrideWith((ref) async => true),
      installIdProvider.overrideWith((ref) async => 'test-install-id'),
      entitlementRepositoryProvider.overrideWithValue(
        MockEntitlementRepository.guest(),
      ),
    ],
    child: MaterialApp.router(
      builder: (context, child) => ScreenUtilInit(
        designSize: const Size(375, 812),
        child: child ?? const SizedBox.shrink(),
      ),
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
  AuthProviderType? lastLoginProvider;

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    lastLoginProvider = provider;
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
    return DeleteAccountResult(session: _session, shouldExitApp: true);
  }
}
