import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_store.dart';

typedef SessionCleanupHook = Future<void> Function(SessionCleanupReason reason);

enum SessionCleanupReason { logout, deleteAccount, refreshFailed, unauthorized }

final sessionCleanupCoordinatorProvider = Provider<SessionCleanupCoordinator>((
  ref,
) {
  return SessionCleanupCoordinator(
    tokenStore: ref.read(authTokenStoreProvider.notifier),
  );
});

/// 统一 session 清理入口。
///
/// 真实 logout/delete/refresh 失败后需要清理 token、feature cache 和播放器资源。本轮先
/// 提供 coordinator 和 hook 机制，不主动接入现有 UI，避免破坏 mock 流程。
class SessionCleanupCoordinator {
  SessionCleanupCoordinator({required AuthTokenStore tokenStore})
    : _tokenStore = tokenStore;

  final AuthTokenStore _tokenStore;
  final List<SessionCleanupHook> _hooks = [];

  void register(SessionCleanupHook hook) {
    _hooks.add(hook);
  }

  Future<void> cleanup(SessionCleanupReason reason) async {
    await _tokenStore.clear();
    for (final hook in List<SessionCleanupHook>.of(_hooks)) {
      await hook(reason);
    }
  }
}
