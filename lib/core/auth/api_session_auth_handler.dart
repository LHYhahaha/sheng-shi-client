import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_refresh_coordinator.dart';
import 'auth_refresh_executor_provider.dart';
import 'auth_token_store.dart';
import 'session_cleanup_coordinator.dart';

final apiSessionAuthHandlerProvider = Provider<ApiSessionAuthHandler>((ref) {
  return ApiSessionAuthHandler(
    refreshCoordinator: ref.watch(authRefreshCoordinatorProvider),
    tokenStore: ref.read(authTokenStoreProvider.notifier),
    readToken: () => ref.read(authTokenStoreProvider),
    sessionCleanup: ref.watch(sessionCleanupCoordinatorProvider),
    refreshExecutor: ref.watch(authRefreshExecutorProvider),
  );
});

/// 401 场景的统一 refresh + cleanup 协调器。
///
/// 只允许由 [ApiClient] 触发；feature 不得直接调用。
class ApiSessionAuthHandler {
  ApiSessionAuthHandler({
    required AuthRefreshCoordinator refreshCoordinator,
    required AuthTokenStore tokenStore,
    required AuthTokenSnapshot Function() readToken,
    required SessionCleanupCoordinator sessionCleanup,
    required AuthRefreshExecutor refreshExecutor,
  }) : _refreshCoordinator = refreshCoordinator,
       _tokenStore = tokenStore,
       _readToken = readToken,
       _sessionCleanup = sessionCleanup,
       _refreshExecutor = refreshExecutor;

  final AuthRefreshCoordinator _refreshCoordinator;
  final AuthTokenStore _tokenStore;
  final AuthTokenSnapshot Function() _readToken;
  final SessionCleanupCoordinator _sessionCleanup;
  final AuthRefreshExecutor _refreshExecutor;

  /// 尝试 refresh；成功返回 true 以便 ApiClient 重试原请求一次。
  Future<bool> handleUnauthorized() async {
    final current = _readToken();
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _sessionCleanup.cleanup(SessionCleanupReason.unauthorized);
      return false;
    }

    try {
      final refreshed = await _refreshCoordinator.refresh(
        () => _refreshExecutor(refreshToken),
      );
      if (refreshed == null || !refreshed.hasAccessToken) {
        await _sessionCleanup.cleanup(SessionCleanupReason.refreshFailed);
        return false;
      }

      await _tokenStore.save(refreshed);
      return true;
    } catch (_) {
      await _sessionCleanup.cleanup(SessionCleanupReason.refreshFailed);
      return false;
    }
  }
}
