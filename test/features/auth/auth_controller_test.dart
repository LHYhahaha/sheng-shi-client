import 'package:drama_client/features/auth/application/auth_controller.dart';
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
}
