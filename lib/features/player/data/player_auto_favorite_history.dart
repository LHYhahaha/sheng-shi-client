import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final playerAutoFavoriteHistoryProvider = Provider(
  (ref) => PlayerAutoFavoriteHistory(),
);

/// Device-local success history. Account cleanup and unfollow must not erase it.
class PlayerAutoFavoriteHistory {
  final Set<String> _succeeded = {};

  String _key(String userId, String dramaId) =>
      'player.auto_favorite.v1.${Uri.encodeComponent(userId)}.'
      '${Uri.encodeComponent(dramaId)}';

  Future<bool> hasSucceeded(String userId, String dramaId) async {
    final key = _key(userId, dramaId);
    if (_succeeded.contains(key)) return true;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key) ?? false;
  }

  Future<void> markSucceeded(String userId, String dramaId) async {
    final key = _key(userId, dramaId);
    // Retain success in memory even if the platform storage write fails.
    _succeeded.add(key);
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(key, true)) {
      throw StateError('Could not persist automatic favorite success');
    }
  }
}
