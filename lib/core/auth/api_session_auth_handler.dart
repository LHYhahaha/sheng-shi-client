import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import 'auth_refresh_coordinator.dart';
import 'auth_refresh_executor_provider.dart';
import 'auth_token_store.dart';
import 'session_cleanup_coordinator.dart';

final apiSessionAuthHandlerProvider = Provider.family<ApiSessionAuthHandler, ApiClient>((ref, apiClient) {
  return ApiSessionAuthHandler(
    refreshCoordinator: ref.watch(authRefreshCoordinatorProvider),
    tokenStore: ref.read(authTokenStoreProvider.notifier),
    readToken: () => ref.read(authTokenStoreProvider),
    sessionCleanup: ref.watch(sessionCleanupCoordinatorProvider),
    // 使用工厂函数创建执行器，传入 ApiClient
    refreshExecutor: createAuthRefreshExecutor(apiClient),
  );
});

/// 401 场景的统一 refresh + cleanup 协调器。
///
/// 只允许由 [ApiClient] 触发；feature 不得直接调用。
/// 
/// Token 刷新策略：
/// 1. accessToken 失效 → 使用 refreshToken 刷新
/// 2. refreshToken 失效 → 清理 session，需要重新登录
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

  /// 处理 401 Unauthorized 响应。
  /// 
  /// 流程：
  /// 1. 检查 refreshToken 是否存在且有效
  /// 2. 如果 refreshToken 已过期 → 清理 session，返回 false（需要重新登录）
  /// 3. 如果 refreshToken 有效 → 尝试刷新 accessToken
  /// 4. 刷新成功 → 保存新 token，返回 true（ApiClient 会重试原请求）
  /// 5. 刷新失败 → 清理 session，返回 false（需要重新登录）
  Future<bool> handleUnauthorized() async {
    final current = _readToken();
    final refreshToken = current.refreshToken;
    final refreshExpiresAt = current.refreshExpiresAt;
    
    print('[ApiSessionAuthHandler] handleUnauthorized called');
    print('[ApiSessionAuthHandler]   hasRefreshToken: ${refreshToken != null && refreshToken.isNotEmpty}');
    print('[ApiSessionAuthHandler]   refreshExpiresAt: $refreshExpiresAt');

    // 检查 refreshToken 是否存在
    if (refreshToken == null || refreshToken.isEmpty) {
      print('[ApiSessionAuthHandler] No refreshToken available, cleaning up session');
      await _sessionCleanup.cleanup(SessionCleanupReason.sessionExpired);
      return false;
    }

    // 检查 refreshToken 是否已过期
    final now = DateTime.now();
    if (refreshExpiresAt != null && now.isAfter(refreshExpiresAt)) {
      print('[ApiSessionAuthHandler] refreshToken expired at $refreshExpiresAt, cleaning up session');
      await _sessionCleanup.cleanup(SessionCleanupReason.sessionExpired);
      return false;
    }

    // 尝试使用 refreshToken 刷新 accessToken
    try {
      print('[ApiSessionAuthHandler] Attempting to refresh accessToken with refreshToken');
      final refreshed = await _refreshCoordinator.refresh(
        () => _refreshExecutor(refreshToken),
      );
      
      if (refreshed == null || !refreshed.hasAccessToken) {
        print('[ApiSessionAuthHandler] Token refresh returned invalid result, cleaning up session');
        await _sessionCleanup.cleanup(SessionCleanupReason.refreshFailed);
        return false;
      }

      print('[ApiSessionAuthHandler] Token refresh successful, saving new token');
      await _tokenStore.save(refreshed);
      return true;
    } catch (e) {
      print('[ApiSessionAuthHandler] Token refresh failed with error: $e, cleaning up session');
      await _sessionCleanup.cleanup(SessionCleanupReason.refreshFailed);
      return false;
    }
  }
}
