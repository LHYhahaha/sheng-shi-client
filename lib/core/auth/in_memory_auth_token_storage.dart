import 'auth_token_snapshot.dart';
import 'auth_token_storage.dart';

/// 进程内 token 存储，用于 mock 与单元测试。
///
/// 应用重启后数据丢失。真实上线前应通过 provider 替换为
/// [FlutterSecureAuthTokenStorage] 或等价 secure 实现。
class InMemoryAuthTokenStorage implements AuthTokenStorage {
  AuthTokenSnapshot? _snapshot;

  @override
  Future<AuthTokenSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(AuthTokenSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = null;
  }
}
