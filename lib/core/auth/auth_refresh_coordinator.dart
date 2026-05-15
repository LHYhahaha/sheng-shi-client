import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_store.dart';

typedef AuthRefreshCallback = Future<AuthTokenSnapshot?> Function();

final authRefreshCoordinatorProvider = Provider<AuthRefreshCoordinator>((ref) {
  return AuthRefreshCoordinator();
});

/// Token refresh queue 的最小骨架。
///
/// 本阶段不接真实 `/auth/refresh`，但先固定“同一时间只有一次 refresh in-flight”的
/// 协调语义。后续 ApiClient 遇到 401 时应通过这里刷新 token，并在成功后重试原请求；
/// refresh 失败则交给 session cleanup 清理本地会话。
class AuthRefreshCoordinator {
  Future<AuthTokenSnapshot?>? _inFlight;

  bool get hasInFlightRefresh => _inFlight != null;

  Future<AuthTokenSnapshot?> refresh(AuthRefreshCallback callback) {
    final running = _inFlight;
    if (running != null) {
      return running;
    }

    late final Future<AuthTokenSnapshot?> future;
    future = callback().whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    _inFlight = future;
    return future;
  }
}
