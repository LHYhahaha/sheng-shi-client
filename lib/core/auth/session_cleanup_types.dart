/// Session 清理触发原因（与 [SessionCleanupCoordinator] 解耦，供 feature 重置状态使用）。
enum SessionCleanupReason {
  logout,
  deleteAccount,
  refreshFailed,
  sessionExpired,
  unauthorized,
}

typedef SessionCleanupHook = Future<void> Function(SessionCleanupReason reason);
