import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/dto/refresh_token_request_dto.dart';
import '../../features/auth/data/remote/auth_remote_data_source.dart';
import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import 'auth_token_snapshot.dart';

/// 使用 refresh token 换取新快照的执行器。
///
/// 由 Auth 模块在 remote 接入时实现（调用 `/api/user/token/refresh`）。
/// 
/// 注意：这个不是 provider，而是一个工厂函数。
/// 这样可以避免循环依赖：apiClientProvider → apiSessionAuthHandlerProvider → authRefreshExecutor
typedef AuthRefreshExecutor =
    Future<AuthTokenSnapshot?> Function(String refreshToken);

/// Token 刷新执行器 provider。
///
/// 在 APP 启动时用于尝试刷新已保存的 token。
final authRefreshExecutorProvider = Provider<AuthRefreshExecutor>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return createAuthRefreshExecutor(apiClient);
});

/// 创建 token 刷新执行器的工厂函数。
/// 
/// 由 apiSessionAuthHandlerProvider 调用，传入 ApiClient 实例。
AuthRefreshExecutor createAuthRefreshExecutor(ApiClient apiClient) {
  return (refreshToken) async {
    try {
      print('[authRefreshExecutor] Starting token refresh with refreshToken: ${refreshToken.substring(0, 20)}...');
      
      final remoteDataSource = AuthRemoteDataSource(apiClient: apiClient);
      final request = RefreshTokenRequestDto(refreshToken: refreshToken);
      final tokenDto = await remoteDataSource.refreshToken(request);
      
      print('[authRefreshExecutor] Token refresh successful');
      print('[authRefreshExecutor]   accessToken: ${tokenDto.accessToken.substring(0, 20)}...');
      print('[authRefreshExecutor]   refreshToken: ${tokenDto.refreshToken.substring(0, 20)}...');
      print('[authRefreshExecutor]   expiresAt: ${tokenDto.expiresAt}');
      print('[authRefreshExecutor]   refreshExpiresAt: ${tokenDto.refreshExpiresAt}');
      
      final snapshot = AuthTokenSnapshot(
        accessToken: tokenDto.accessToken,
        refreshToken: tokenDto.refreshToken,
        tokenType: tokenDto.tokenType,
        expiresAt: tokenDto.expiresAt,
        refreshExpiresAt: tokenDto.refreshExpiresAt,
        sessionKind: AuthTokenSessionKind.guest,
      );
      
      return snapshot;
    } catch (e) {
      print('[authRefreshExecutor] Token refresh failed: $e');
      return null;
    }
  };
}
