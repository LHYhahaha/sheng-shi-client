import 'package:shared_preferences/shared_preferences.dart';

import '../domain/search_history_repository.dart';

class SharedPreferencesSearchHistoryRepository
    implements SearchHistoryRepository {
  static const _keyPrefix = 'search_history.v1.';

  @override
  Future<List<String>> read(String userKey) async {
    final preferences = await SharedPreferences.getInstance();
    return List<String>.unmodifiable(
      preferences.getStringList(_key(userKey)) ?? const [],
    );
  }

  @override
  Future<void> write(String userKey, List<String> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key(userKey), items);
  }

  @override
  Future<void> clear(String userKey) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userKey));
  }

  String _key(String userKey) => '$_keyPrefix${Uri.encodeComponent(userKey)}';
}
