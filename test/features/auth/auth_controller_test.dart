import 'dart:async';

import 'package:drama_client/features/auth/application/auth_controller.dart';
import 'package:drama_client/features/auth/data/auth_repository_provider.dart';
import 'package:drama_client/features/auth/domain/auth_repository.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:drama_client/features/auth/domain/delete_account_result.dart';
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

  test('login failure clears pending provider and remains retryable', () async {
    final repository = _FailingAuthRepository(failLogin: true);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    await controller.login(AuthProviderType.google);
    var state = container.read(authControllerProvider);

    expect(state.isLoggedIn, isFalse);
    expect(state.pendingProvider, isNull);
    expect(state.error, isA<StateError>());

    repository.failLogin = false;
    await controller.login(AuthProviderType.google);
    state = container.read(authControllerProvider);

    expect(state.isLoggedIn, isTrue);
    expect(state.user?.nickname, 'Google User');
    expect(state.error, isNull);
  });

  test('load failure keeps guest state and can retry', () async {
    final repository = _FailingAuthRepository(failFetch: true);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    await controller.load();
    var state = container.read(authControllerProvider);

    expect(state.isLoading, isFalse);
    expect(state.isLoggedIn, isFalse);
    expect(state.failedAction, AuthFailureAction.load);
    expect(state.error, isA<StateError>());

    repository.failFetch = false;
    await controller.load();
    state = container.read(authControllerProvider);

    expect(state.error, isNull);
    expect(state.isLoggedIn, isFalse);
  });

  test('logout and delete failures keep user and are retryable', () async {
    final repository = _FailingAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);

    await controller.login(AuthProviderType.device);
    repository.failLogout = true;
    await controller.logout();
    var state = container.read(authControllerProvider);

    expect(state.isLoggedIn, isTrue);
    expect(state.failedAction, AuthFailureAction.logout);
    expect(state.error, isA<StateError>());

    repository.failLogout = false;
    await controller.logout();
    state = container.read(authControllerProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.error, isNull);

    await controller.login(AuthProviderType.facebook);
    repository.failDelete = true;
    await controller.deleteAccount();
    state = container.read(authControllerProvider);

    expect(state.isLoggedIn, isTrue);
    expect(state.failedAction, AuthFailureAction.deleteAccount);
    expect(state.error, isA<StateError>());

    repository.failDelete = false;
    await controller.deleteAccount();
    state = container.read(authControllerProvider);
    expect(state.isLoggedIn, isFalse);
    expect(state.error, isNull);
  });
}

class _BlockingAuthRepository implements AuthRepository {
  Completer<AuthSession>? _loginCompleter;
  int loginCalls = 0;

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
  Future<DeleteAccountResult> deleteAccount() async => DeleteAccountResult(
    session: const AuthSession.guest(),
    shouldExitApp: true,
  );
}

class _FailingAuthRepository implements AuthRepository {
  _FailingAuthRepository({this.failFetch = false, this.failLogin = false});

  bool failFetch;
  bool failLogin;
  bool failLogout = false;
  bool failDelete = false;
  AuthSession _session = const AuthSession.guest();

  @override
  Future<AuthSession> login(AuthProviderType provider) async {
    if (failLogin) {
      throw StateError('login failed');
    }
    _session = AuthSession(
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
    return DeleteAccountResult(
      session: _session,
      shouldExitApp: true,
    );
  }
}
