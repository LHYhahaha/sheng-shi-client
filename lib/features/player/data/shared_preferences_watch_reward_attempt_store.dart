import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/watch_reward_repository.dart';

final watchRewardAttemptStoreProvider = Provider<WatchRewardAttemptStore>(
  (ref) => SharedPreferencesWatchRewardAttemptStore(),
);

class SharedPreferencesWatchRewardAttemptStore
    implements WatchRewardAttemptStore {
  static const _prefix = 'player.watch_reward_attempts.v1.';
  String _key(String user, String day) =>
      '$_prefix${Uri.encodeComponent(user)}.$day';

  @override
  Future<Map<String, WatchRewardAttempt>> read(
    String userId,
    String dayKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId, dayKey));
    if (raw == null) return {};
    // Corrupt or unavailable retry history must not silently grant a new budget.
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final result = <String, WatchRewardAttempt>{};
    for (final entry in json.entries) {
      final value = entry.value as Map<String, dynamic>;
      final count = value['count'] as int;
      final seconds = value['seconds'] as int;
      if (count < 0 || count > 4 || seconds < 0) {
        throw const FormatException('Invalid watch reward attempt history');
      }
      result[entry.key] = WatchRewardAttempt(
        count: count,
        lastAttemptSeconds: seconds,
        succeeded: value['succeeded'] as bool,
      );
    }
    return result;
  }

  @override
  Future<void> write(
    String userId,
    String dayKey,
    Map<String, WatchRewardAttempt> attempts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _key(userId, dayKey),
      jsonEncode({
        for (final entry in attempts.entries)
          entry.key: {
            'count': entry.value.count,
            'seconds': entry.value.lastAttemptSeconds,
            'succeeded': entry.value.succeeded,
          },
      }),
    );
    if (!saved) throw StateError('Failed to save watch reward attempts');
    final cutoff = DateTime.parse(
      '${dayKey}T00:00:00Z',
    ).subtract(const Duration(days: 6));
    final userPrefix = '$_prefix${Uri.encodeComponent(userId)}.';
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(userPrefix),
    )) {
      final day = DateTime.tryParse(
        '${key.substring(userPrefix.length)}T00:00:00Z',
      );
      if (day != null && day.isBefore(cutoff)) await prefs.remove(key);
    }
  }
}
