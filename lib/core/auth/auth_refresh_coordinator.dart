import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_snapshot.dart';

typedef AuthRefreshCallback = Future<AuthTokenSnapshot?> Function();

final authRefreshCoordinatorProvider = Provider<AuthRefreshCoordinator>((ref) {
  return AuthRefreshCoordinator();
});

/// Token refresh queue 的最小骨架。
///
/// 固定“同一时间只有一次 refresh in-flight”的协调语义。
/// ApiClient 遇到 401 时通过 [ApiSessionAuthHandler] 调用这里；成功后重试原请求一次；
/// refresh 失败则交给 [SessionCleanupCoordinator] 清理本地会话。
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
