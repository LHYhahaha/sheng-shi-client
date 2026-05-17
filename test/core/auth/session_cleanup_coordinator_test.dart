import 'dart:async';

import 'package:drama_client/core/auth/auth_token_snapshot.dart';
import 'package:drama_client/core/auth/auth_token_store.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';
import 'package:drama_client/core/auth/session_cleanup_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanup clears token and invokes hooks with reason', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(authTokenStoreProvider.notifier)
        .save(const AuthTokenSnapshot(accessToken: 'token-1'));
    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    final reasons = <SessionCleanupReason>[];
    coordinator.register((reason) async {
      reasons.add(reason);
    });

    await coordinator.cleanup(SessionCleanupReason.logout);

    expect(container.read(authTokenStoreProvider).hasAccessToken, isFalse);
    expect(reasons, [SessionCleanupReason.logout]);
  });

  test('failed hook does not block other hooks', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    final executed = <int>[];
    coordinator.register((_) async {
      executed.add(1);
      throw StateError('hook-1 failed');
    });
    coordinator.register((_) async {
      executed.add(2);
    });

    await coordinator.cleanup(SessionCleanupReason.refreshFailed);

    expect(executed, [1, 2]);
  });

  test('async hooks are awaited before cleanup completes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    final completer = Completer<void>();
    var hookFinished = false;
    coordinator.register((_) async {
      await completer.future;
      hookFinished = true;
    });

    final cleanupFuture = coordinator.cleanup(
      SessionCleanupReason.deleteAccount,
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(hookFinished, isFalse);

    completer.complete();
    await cleanupFuture;
    expect(hookFinished, isTrue);
  });

  test('concurrent cleanup shares single in-flight run', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    var hookCalls = 0;
    final gate = Completer<void>();
    coordinator.register((_) async {
      hookCalls += 1;
      await gate.future;
    });

    final first = coordinator.cleanup(SessionCleanupReason.sessionExpired);
    final second = coordinator.cleanup(SessionCleanupReason.logout);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(hookCalls, 1);

    gate.complete();
    await Future.wait([first, second]);
    expect(hookCalls, 1);
  });

  test('registerFeatureHooks only registers once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    var calls = 0;
    coordinator.registerFeatureHooks([
      (_) async {
        calls += 1;
      },
    ]);
    coordinator.registerFeatureHooks([
      (_) async {
        calls += 1;
      },
    ]);

    await coordinator.cleanup(SessionCleanupReason.logout);
    expect(calls, 1);
  });
}
