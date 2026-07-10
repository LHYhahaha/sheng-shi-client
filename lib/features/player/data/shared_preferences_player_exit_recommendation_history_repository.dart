import 'package:shared_preferences/shared_preferences.dart';

import '../domain/player_exit_recommendation_history_repository.dart';

class SharedPreferencesPlayerExitRecommendationHistoryRepository
    implements PlayerExitRecommendationHistoryRepository {
  static const _keyPrefix = 'player.exit_recommendation_shown.v1.';

  @override
  Future<bool> hasShown({
    required String userKey,
    required String dramaId,
  }) async {
    final id = dramaId.trim();
    if (id.isEmpty) {
      return false;
    }
    final preferences = await SharedPreferences.getInstance();
    final shownDramaIds = preferences.getStringList(_key(userKey)) ?? const [];
    return shownDramaIds.contains(id);
  }

  @override
  Future<void> markShown({
    required String userKey,
    required String dramaId,
  }) async {
    final id = dramaId.trim();
    if (id.isEmpty) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final key = _key(userKey);
    final current = preferences.getStringList(key) ?? const [];
    if (current.contains(id)) {
      return;
    }
    await preferences.setStringList(key, [id, ...current]);
  }

  String _key(String userKey) => '$_keyPrefix${Uri.encodeComponent(userKey)}';
}
