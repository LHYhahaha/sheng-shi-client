import 'install_id_storage.dart';

/// 进程内 install id 存储，用于单元测试。
class InMemoryInstallIdStorage implements InstallIdStorage {
  String? _installId;

  @override
  Future<String?> read() async => _installId;

  @override
  Future<void> write(String installId) async {
    _installId = installId;
  }

  @override
  Future<void> clear() async {
    _installId = null;
  }
}
