import 'auth_token_snapshot.dart';

/// Token 持久化抽象。
///
/// [AuthTokenStore] 是唯一读写入口；feature/UI 不得直接依赖具体实现。
/// 真实阶段默认应使用 secure storage；当前联调前可继续 in-memory 默认实现。
abstract interface class AuthTokenStorage {
  Future<AuthTokenSnapshot?> read();

  Future<void> write(AuthTokenSnapshot snapshot);

  /// 必须清掉 access / refresh / 过期时间等全部字段。
  Future<void> clear();
}
