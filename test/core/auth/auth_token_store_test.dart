import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drama_client/core/auth/api_session_auth_handler.dart';
import 'package:drama_client/core/auth/auth_refresh_coordinator.dart';
import 'package:drama_client/core/auth/auth_token_storage_provider.dart';
import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/auth/in_memory_auth_token_storage.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';

void main() {
  test('token store writes through storage abstraction', () async {
    final storage = InMemoryAuthTokenStorage();
    final container = ProviderContainer(
      overrides: [authTokenStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(
          const AuthTokenSnapshot(accessToken: 'persisted', refreshToken: 'r1'),
        );

    expect(await storage.read(), isNotNull);
    expect((await storage.read())!.accessToken, 'persisted');
  });

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

  test('refresh coordinator clears in-flight state after failure', () async {
    final coordinator = AuthRefreshCoordinator();
    var calls = 0;

    Future<AuthTokenSnapshot?> refresh() async {
      calls += 1;
      throw StateError('refresh failed');
    }

    await expectLater(coordinator.refresh(refresh), throwsStateError);

    expect(calls, 1);
    expect(coordinator.hasInFlightRefresh, isFalse);

    await expectLater(coordinator.refresh(refresh), throwsStateError);

    expect(calls, 2);
  });

  test('api session auth handler refreshes tokens on unauthorized', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(
          const AuthTokenSnapshot(
            accessToken: 'access-old',
            refreshToken: 'refresh-1',
          ),
        );

    final handler = ApiSessionAuthHandler(
      refreshCoordinator: AuthRefreshCoordinator(),
      tokenStore: container.read(authTokenStoreProvider.notifier),
      readToken: () => container.read(authTokenStoreProvider),
      sessionCleanup: container.read(sessionCleanupCoordinatorProvider),
      refreshExecutor: (refreshToken) async {
        return AuthTokenSnapshot(
          accessToken: 'access-refreshed',
          refreshToken: refreshToken,
        );
      },
    );

    expect(await handler.handleUnauthorized(), isTrue);
    expect(
      container.read(authTokenStoreProvider).accessToken,
      'access-refreshed',
    );
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
