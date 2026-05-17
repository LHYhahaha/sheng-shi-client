import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_store.dart';
import 'guest_session_bootstrap.dart';
import 'session_cleanup_types.dart';

export 'session_cleanup_types.dart';

final sessionCleanupCoordinatorProvider = Provider<SessionCleanupCoordinator>((
  ref,
) {
  return SessionCleanupCoordinator(
    tokenStore: ref.read(authTokenStoreProvider.notifier),
    guestBootstrap: ref.read(guestSessionBootstrapProvider),
  );
});

/// 统一 session 清理入口。
///
/// 真实 API 阶段在 logout / refresh 失败 / session 失效后必须清理 token 与各 feature
/// 缓存，随后经 [GuestSessionBootstrap] 恢复 **guest session**（非空 logged-out）。
/// feature hook 在 [featureSessionCleanupRegistrationProvider] 注册，core 不得
/// import features。
class SessionCleanupCoordinator {
  SessionCleanupCoordinator({
    required AuthTokenStore tokenStore,
    GuestSessionBootstrap? guestBootstrap,
  }) : _tokenStore = tokenStore,
       _guestBootstrap = guestBootstrap ?? const GuestSessionBootstrap();

  final AuthTokenStore _tokenStore;
  final GuestSessionBootstrap _guestBootstrap;
  final List<SessionCleanupHook> _hooks = [];
  Future<void>? _inFlight;
  var _featureHooksRegistered = false;

  void register(SessionCleanupHook hook) {
    _hooks.add(hook);
  }

  void registerFeatureHooks(Iterable<SessionCleanupHook> hooks) {
    if (_featureHooksRegistered) {
      return;
    }
    _featureHooksRegistered = true;
    _hooks.addAll(hooks);
  }

  Future<void> cleanup(SessionCleanupReason reason) async {
    final running = _inFlight;
    if (running != null) {
      return running;
    }

    late final Future<void> future;
    future = _runCleanup(reason).whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    _inFlight = future;
    return future;
  }

  Future<void> _runCleanup(SessionCleanupReason reason) async {
    await _tokenStore.clear();

    for (final hook in List<SessionCleanupHook>.of(_hooks)) {
      try {
        await hook(reason);
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'session_cleanup_coordinator',
            context: ErrorDescription(
              'Session cleanup hook failed for reason=$reason',
            ),
          ),
        );
      }
    }

    try {
      await _guestBootstrap.bootstrapAfterSessionCleanup(reason);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'session_cleanup_coordinator',
          context: ErrorDescription(
            'Guest session bootstrap failed after cleanup reason=$reason',
          ),
        ),
      );
    }
  }
}
