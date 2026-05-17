import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_snapshot.dart';

/// 使用 refresh token 换取新快照的执行器。
///
/// 由 Auth 模块在 remote 接入时实现（调用 `/auth/refresh`）。默认返回 null，
/// 表示尚未配置真实 refresh；ApiClient 收到 401 后会走 cleanup。
typedef AuthRefreshExecutor =
    Future<AuthTokenSnapshot?> Function(String refreshToken);

final authRefreshExecutorProvider = Provider<AuthRefreshExecutor>((ref) {
  return (_) async => null;
});
