import 'user_info_storage.dart';
import 'user_info_store.dart';

/// 用户信息内存存储实现。
///
/// 用于开发和测试阶段。真实阶段应替换为 secure storage 或本地数据库。
class InMemoryUserInfoStorage implements UserInfoStorage {
  UserInfoSnapshot? _cached;

  @override
  Future<UserInfoSnapshot?> read() async {
    return _cached;
  }

  @override
  Future<void> write(UserInfoSnapshot snapshot) async {
    _cached = snapshot;
  }

  @override
  Future<void> clear() async {
    _cached = null;
  }
}
