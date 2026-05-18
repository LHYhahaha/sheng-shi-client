import 'package:drama_client/app/app_root_navigator_key.dart';
import 'package:drama_client/app/router/route_paths.dart';
import 'package:drama_client/bootstrap/feature_session_cleanup.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';
import 'package:drama_client/core/modal/app_modal_host.dart';
import 'package:drama_client/core/toast/app_toast_provider.dart';
import 'package:drama_client/features/auth/application/account_cancellation_controller.dart';
import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/data/mock_auth_repository.dart';
import 'package:drama_client/features/auth/data/session_cleanup_auth_repository.dart';
import 'package:drama_client/features/auth/domain/account_deletion_exception.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/presentation/pages/account_cancellation_page.dart';
import 'package:drama_client/features/profile/presentation/pages/settings_page.dart';
import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:drama_client/bootstrap/app_modal_registry_bootstrap.dart';

import '../../core/toast/recording_app_toast_service.dart';

void main() {
  group('Settings', () {
    testWidgets('shows three settings entries', (tester) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: RoutePaths.settings),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_account_cancellation_row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_user_agreement_row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_privacy_policy_row')),
        findsOneWidget,
      );
      expect(find.text('Account cancellation'), findsOneWidget);
      expect(find.text('User Agreement'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('account cancellation row opens cancellation page', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: RoutePaths.settings),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('settings_account_cancellation_row')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete account (9s)'), findsOneWidget);
    });
  });

  group('AccountCancellationPage', () {
    testWidgets(
      'default unchecked and delete button disabled with countdown label',
      (tester) async {
        await tester.pumpWidget(
          _buildRouterTestApp(initialLocation: RoutePaths.accountCancellation),
        );
        await tester.pump();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(AccountCancellationPage)),
        );
        expect(
          container.read(accountCancellationControllerProvider).acceptedRisk,
          isFalse,
        );
        expect(find.byType(Checkbox), findsNothing);

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('account_cancellation_delete_button')),
        );
        expect(button.onPressed, isNull);
        expect(find.text('Delete account (9s)'), findsOneWidget);
      },
    );

    testWidgets('shows Figma deletion rows, risk copy, and icon assets', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: RoutePaths.accountCancellation),
      );
      await tester.pump();

      expect(
        find.text('Please confirm the information to be deleted:'),
        findsOneWidget,
      );
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Third-party account information'), findsOneWidget);
      expect(find.text('Account balance'), findsOneWidget);
      expect(find.text('Your balance'), findsOneWidget);
      expect(find.text('Member benefits'), findsOneWidget);
      expect(
        find.text(
          'Your personal information (email address and nickname will be deleted)',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Consumption History, Recharge History, Chapter Unlock History, Series in My List.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your Coin balance is zero. You may delete your account if desired.',
        ),
        findsOneWidget,
      );
      expect(find.text('You’re not a member yet'), findsOneWidget);
      expect(
        find.text(
          'To ensure proper access, please log out from the account on other devices',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'All information of this account will be deleted and cannot be retrieved.',
        ),
        findsOneWidget,
      );

      expect(_assetImage('personal_info.png'), findsOneWidget);
      expect(_assetImage('third_party_account.png'), findsOneWidget);
      expect(_assetImage('account_balance.png'), findsOneWidget);
      expect(_assetImage('your_balance.png'), findsOneWidget);
      expect(_assetImage('member_benefits.png'), findsOneWidget);
      expect(_assetImage('warning.png'), findsOneWidget);
    });

    testWidgets('countdown finished without checkbox keeps button disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouterTestApp(
          initialLocation: RoutePaths.accountCancellation,
          extraOverrides: [
            accountCancellationCountdownProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('account_cancellation_delete_button')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('countdown updates delete button label', (tester) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: RoutePaths.accountCancellation),
      );
      await tester.pump();
      expect(find.text('Delete account (9s)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Delete account (8s)'), findsOneWidget);
    });

    testWidgets('checked before countdown finished keeps button disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouterTestApp(initialLocation: RoutePaths.accountCancellation),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_risk_checkbox')),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('account_cancellation_delete_button')),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('Delete account ('), findsOneWidget);
    });

    testWidgets('checked after countdown enables delete button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouterTestApp(
          initialLocation: RoutePaths.accountCancellation,
          extraOverrides: [
            accountCancellationCountdownProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_risk_checkbox')),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('account_cancellation_delete_button')),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('delete tap shows AppModal confirm', (tester) async {
      await tester.pumpWidget(
        _buildRouterTestApp(
          initialLocation: RoutePaths.accountCancellation,
          extraOverrides: [
            accountCancellationCountdownProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_risk_checkbox')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_delete_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete account?'), findsOneWidget);
      expect(
        find.text(
          'Deleted account data cannot be recovered. Do you want to continue?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancel confirm does not delete account', (tester) async {
      final repository = _CountingAuthRepository();
      await tester.pumpWidget(
        _buildRouterTestApp(
          initialLocation: RoutePaths.accountCancellation,
          authRepository: repository,
          extraOverrides: [
            accountCancellationCountdownProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_risk_checkbox')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_delete_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AccountCancellationPage), findsOneWidget);
      expect(repository.deleteAccountCalls, 0);
    });

    testWidgets('confirm delete returns to profile guest', (tester) async {
      final repository = _CountingAuthRepository();
      await repository.login(AuthProviderType.google);

      await tester.pumpWidget(
        _buildRouterTestApp(
          initialLocation: RoutePaths.accountCancellation,
          authRepository: repository,
          extraOverrides: [
            accountCancellationCountdownProvider.overrideWithValue(0),
          ],
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccountCancellationPage)),
      );
      await container.read(authControllerProvider.notifier).load();
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_risk_checkbox')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('account_cancellation_delete_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Confirm delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Profile guest marker'), findsOneWidget);
      expect(repository.deleteAccountCalls, 1);
      expect(container.read(authControllerProvider).session.isGuest, isTrue);
    });
  });

  test('deleteAccount through repository triggers session cleanup', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) {
          return SessionCleanupAuthRepository(
            delegate: MockAuthRepository(),
            sessionCleanup: ref.read(sessionCleanupCoordinatorProvider),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(featureSessionCleanupRegistrationProvider);

    final reasons = <SessionCleanupReason>[];
    container.read(sessionCleanupCoordinatorProvider).register((reason) async {
      reasons.add(reason);
    });

    await container.read(authRepositoryProvider).login(AuthProviderType.google);
    await container.read(authRepositoryProvider).deleteAccount();

    expect(reasons, [SessionCleanupReason.deleteAccount]);
  });

  test('mock delete rejection surfaces business error', () async {
    final repository = MockAuthRepository()
      ..forcedDeleteRejection = const AccountDeletionRejectedException(
        code: 'NON_ZERO_BALANCE',
        message: 'Paid coin balance must be zero before deleting your account.',
      );

    expect(
      repository.deleteAccount(),
      throwsA(isA<AccountDeletionRejectedException>()),
    );
  });
}

class _CountingAuthRepository implements AuthRepository {
  int deleteAccountCalls = 0;
  AuthSession _session = const AuthSession.guest();

  @override
  Future<AuthSession> fetchSession() async => _session;

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    _session = AuthSession(
      user: AuthUser(
        id: '1',
        nickname: 'Test',
        avatarAssetPath: authDefaultAvatarAssetPath,
        provider: provider,
      ),
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
    deleteAccountCalls += 1;
    _session = const AuthSession.guest();
    return _session;
  }
}

Finder _assetImage(String fileName) {
  final path = 'assets/images/auth/account_cancellation/$fileName';
  return find.byWidgetPredicate((widget) {
    if (widget is! Image) {
      return false;
    }
    final image = widget.image;
    return image is AssetImage && image.assetName == path;
  });
}

Widget _buildRouterTestApp({
  required String initialLocation,
  AuthRepository? authRepository,
  AuthRepository Function(Ref ref)? authRepositoryFactory,
  List extraOverrides = const [],
}) {
  final toast = RecordingAppToastService();
  final router = GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.accountCancellation,
        builder: (context, state) => const AccountCancellationPage(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) =>
            const Scaffold(body: Text('Profile guest marker')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      if (authRepositoryFactory != null)
        authRepositoryProvider.overrideWith(authRepositoryFactory)
      else
        authRepositoryProvider.overrideWithValue(
          authRepository ?? MockAuthRepository(),
        ),
      appToastProvider.overrideWithValue(toast),
      ...appModalRegistryOverrides,
      ...extraOverrides,
    ],
    child: MaterialApp.router(
      builder: (context, child) => AppModalHost(child: child),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}
