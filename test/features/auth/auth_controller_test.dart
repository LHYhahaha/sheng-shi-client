import 'dart:async';

import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts as guest and logs in with mock provider', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.load();

    expect(container.read(authControllerProvider).isLoggedIn, isFalse);

    await controller.login(AuthProviderType.google);

    final state = container.read(authControllerProvider);
    expect(state.isLoggedIn, isTrue);
    expect(state.user?.nickname, 'Google User');
    expect(state.user?.provider, AuthProviderType.google);
  });

  test('logs out and deletes account back to guest state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(AuthProviderType.facebook);
    expect(container.read(authControllerProvider).isLoggedIn, isTrue);

    await controller.logout();
    expect(container.read(authControllerProvider).isLoggedIn, isFalse);

    await controller.login(AuthProviderType.device);
    expect(container.read(authControllerProvider).isLoggedIn, isTrue);

    await controller.deleteAccount();
    expect(container.read(authControllerProvider).isLoggedIn, isFalse);
  });

  test('ignores repeated login taps while a provider is pending', () async {
    final repository = _BlockingAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    final firstLogin = controller.login(AuthProviderType.google);
    await Future<void>.delayed(Duration.zero);

    await controller.login(AuthProviderType.facebook);

    expect(repository.loginCalls, 1);
    repository.completeLogin(AuthProviderType.google);
    await firstLogin;

    final state = container.read(authControllerProvider);
    expect(state.user?.provider, AuthProviderType.google);
    expect(state.pendingProvider, isNull);
  });
}

class _BlockingAuthRepository implements AuthRepository {
  Completer<AuthSession>? _loginCompleter;
  int loginCalls = 0;

  @override
  Future<AuthSession> fetchSession() async => const AuthSession.guest();

  @override
  Future<AuthSession> login(AuthProviderType provider) {
    loginCalls += 1;
    _loginCompleter = Completer<AuthSession>();
    return _loginCompleter!.future;
  }

  void completeLogin(AuthProviderType provider) {
    _loginCompleter?.complete(
      AuthSession(
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
      ),
    );
  }

  @override
  Future<AuthSession> logout() async => const AuthSession.guest();

  @override
  Future<AuthSession> deleteAccount() async => const AuthSession.guest();
}
