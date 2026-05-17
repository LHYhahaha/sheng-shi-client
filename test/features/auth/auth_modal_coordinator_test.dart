import 'package:drama_client/core/modal/app_modal_provider.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/auth/application/auth_modal_coordinator.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_login_intent.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_modal_channels.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_modal_payloads.dart';
import 'package:drama_client/features/auth/presentation/modal/auth_modal_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recording_app_modal_service.dart';

void main() {
  group('AuthModalCoordinator', () {
    late RecordingAppModalService modalService;
    late ProviderContainer container;

    setUp(() {
      modalService = RecordingAppModalService();
      container = ProviderContainer(
        overrides: [
          appModalServiceProvider.overrideWithValue(modalService),
          authRepositoryProvider.overrideWithValue(
            _CoordinatorAuthRepository(),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('showLogin enqueues auth.login channel request', (
      tester,
    ) async {
      await tester.pumpWidget(_host(container));
      final coordinator = container.read(authModalCoordinatorProvider);
      final context = tester.element(find.byType(Placeholder));

      await coordinator.showLogin(context);
      await tester.pump();

      expect(modalService.requests, hasLength(1));
      final request = modalService.requests.single as FeatureAppModalRequest;
      expect(request.channel, AuthModalChannels.login);
      expect(request.type, AppModalType.login);
      expect(request.source, AppModalSource.auth);
    });

    testWidgets('showLogin returns preset success result', (tester) async {
      modalService.defaultGenericResult = const LoginModalResult.success(
        provider: 'google',
        userId: '1',
        userNickname: 'Google User',
      );
      await tester.pumpWidget(_host(container));
      final coordinator = container.read(authModalCoordinatorProvider);
      final context = tester.element(find.byType(Placeholder));

      final result = await coordinator.showLogin(context);
      expect(result.isSuccess, isTrue);
      expect(result, isA<AuthLoginModalSuccess>());
      expect((result as AuthLoginModalSuccess).provider, AuthProviderType.google);
    });

    testWidgets('showLoginRequired sets loginRequired intent in payload', (
      tester,
    ) async {
      await tester.pumpWidget(_host(container));
      final coordinator = container.read(authModalCoordinatorProvider);
      final context = tester.element(find.byType(Placeholder));

      await coordinator.showLoginRequired(
        context,
        reason: AuthLoginRequiredReason.wallet,
      );

      final request = modalService.requests.single as FeatureAppModalRequest;
      final payload = request.payload! as AuthLoginModalPayload;
      expect(payload.intent, AuthLoginIntent.loginRequired);
      expect(payload.reason, AuthLoginRequiredReason.wallet);
      expect(request.source, AppModalSource.wallet);
    });

    testWidgets('showLogin skips modal when already authenticated', (
      tester,
    ) async {
      final signedIn = _CoordinatorAuthRepository(
        session: _sessionFor(AuthProviderType.google),
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          appModalServiceProvider.overrideWithValue(modalService),
          authRepositoryProvider.overrideWithValue(signedIn),
        ],
      );

      await tester.pumpWidget(_host(container));
      await container.read(authControllerProvider.notifier).load();
      final coordinator = container.read(authModalCoordinatorProvider);
      final context = tester.element(find.byType(Placeholder));

      final result = await coordinator.showLogin(context);

      expect(modalService.requests, isEmpty);
      expect(result.isSuccess, isTrue);
      expect((result as AuthLoginModalSuccess).user.nickname, 'Google User');
    });

    test('dismissAuthModals dismisses auth source modals', () {
      final coordinator = container.read(authModalCoordinatorProvider);
      coordinator.dismissAuthModals();
      expect(modalService.dismissForSourceCalls, [AppModalSource.auth]);
    });
  });
}

Widget _host(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: Placeholder()),
  );
}

class _CoordinatorAuthRepository implements AuthRepository {
  _CoordinatorAuthRepository({AuthSession? session})
    : _session = session ?? const AuthSession.guest();

  AuthSession _session;

  @override
  Future<AuthSession> fetchSession() async => _session;

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    _session = _sessionFor(provider);
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

AuthSession _sessionFor(AuthProviderType provider) {
  return AuthSession(
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
}
