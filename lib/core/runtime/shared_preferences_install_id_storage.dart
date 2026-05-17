import 'package:shared_preferences/shared_preferences.dart';

import 'install_id_storage.dart';

/// 使用 [SharedPreferences] 持久化 install id（已有依赖，无需新增包）。
class SharedPreferencesInstallIdStorage implements InstallIdStorage {
  SharedPreferencesInstallIdStorage(this._preferences);

  static const _key = 'drama.install_id';

  final SharedPreferences _preferences;

  @override
  Future<String?> read() async {
    final value = _preferences.getString(_key);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  @override
  Future<void> write(String installId) async {
    await _preferences.setString(_key, installId);
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_key);
  }
}
