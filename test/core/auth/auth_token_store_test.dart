import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drama_client/core/auth/auth_refresh_coordinator.dart';
import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';

void main() {
  test('in-memory token store saves and clears token snapshot', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(
          AuthTokenSnapshot(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            expiresAt: DateTime.parse('2026-05-15T10:00:00Z'),
          ),
        );

    expect(container.read(authTokenStoreProvider).accessToken, 'access-1');
    expect(container.read(authTokenStoreProvider).refreshToken, 'refresh-1');

    await container.read(authTokenStoreProvider.notifier).clear();

    expect(container.read(authTokenStoreProvider).accessToken, isNull);
    expect(container.read(authTokenStoreProvider).hasAccessToken, isFalse);
  });

  test('refresh coordinator deduplicates in-flight refresh work', () async {
    final coordinator = AuthRefreshCoordinator();
    var calls = 0;

    Future<AuthTokenSnapshot?> refresh() async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return const AuthTokenSnapshot(accessToken: 'new-access');
    }

    final first = coordinator.refresh(refresh);
    final second = coordinator.refresh(refresh);

    expect(identical(first, second), isTrue);
    expect((await first)?.accessToken, 'new-access');
    expect(await second, isNotNull);
    expect(calls, 1);
    expect(coordinator.hasInFlightRefresh, isFalse);
  });

  test('session cleanup clears token and invokes registered hooks', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(const AuthTokenSnapshot(accessToken: 'access-1'));
    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    final reasons = <SessionCleanupReason>[];
    coordinator.register((reason) async {
      reasons.add(reason);
    });

    await coordinator.cleanup(SessionCleanupReason.logout);

    expect(container.read(authTokenStoreProvider).accessToken, isNull);
    expect(reasons, [SessionCleanupReason.logout]);
  });
}
