import 'user_info_store.dart';

/// 用户信息持久化抽象。
///
/// [UserInfoStore] 是唯一读写入口；feature/UI 不得直接依赖具体实现。
/// 真实阶段可使用本地数据库或 SharedPreferences；当前联调前可继续 in-memory 默认实现。
abstract interface class UserInfoStorage {
  Future<UserInfoSnapshot?> read();

  Future<void> write(UserInfoSnapshot snapshot);

  /// 必须清掉全部用户信息字段。
  Future<void> clear();
}
