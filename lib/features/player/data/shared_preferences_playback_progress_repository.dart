import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/player_playback_progress.dart';

/// Local persistent playback progress repository.
///
/// It stores a tiny JSON payload per item so returning to a watched episode can
/// restore progress immediately without waiting for the remote watch API.
class SharedPreferencesPlaybackProgressRepository
    implements PlaybackProgressRepository {
  static const _prefix = 'player.playback_progress.';
  static const _cleanupMarkerKey = 'player.playback_progress_cleanup_at_ms';
  static const _maxEntries = 120;
  static const _entryTtl = Duration(days: 30);
  static const _cleanupInterval = Duration(hours: 24);

  @override
  Future<PlaybackProgress?> getProgress(String itemId) async {
    final preferences = await _preferencesOrNull();
    if (preferences == null) {
      return null;
    }
    await _cleanupIfDue(preferences);
    final raw = preferences.getString('$_prefix$itemId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final positionMs = json['positionMs'] as int? ?? 0;
      final durationMs = json['durationMs'] as int? ?? 0;
      final updatedAtMs = json['updatedAtMs'] as int? ?? 0;
      return PlaybackProgress(
        itemId: itemId,
        position: Duration(milliseconds: positionMs),
        duration: Duration(milliseconds: durationMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    } catch (_) {
      await preferences.remove('$_prefix$itemId');
      return null;
    }
  }

  @override
  Future<void> saveProgress(PlaybackProgress progress) async {
    final preferences = await _preferencesOrNull();
    if (preferences == null) {
      return;
    }
    await _cleanupIfDue(preferences);
    final payload = <String, int>{
      'positionMs': progress.position.inMilliseconds,
      'durationMs': progress.duration.inMilliseconds,
      'updatedAtMs': progress.updatedAt.millisecondsSinceEpoch,
    };
    await preferences.setString(
      '$_prefix${progress.itemId}',
      jsonEncode(payload),
    );
  }

  Future<SharedPreferences?> _preferencesOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cleanupIfDue(SharedPreferences preferences) async {
    final now = DateTime.now();
    final lastCleanupMs = preferences.getInt(_cleanupMarkerKey) ?? 0;
    final lastCleanup = DateTime.fromMillisecondsSinceEpoch(lastCleanupMs);
    if (lastCleanupMs > 0 && now.difference(lastCleanup) < _cleanupInterval) {
      return;
    }
    await preferences.setInt(
      _cleanupMarkerKey,
      now.millisecondsSinceEpoch,
    );
    await _cleanup(preferences, now);
  }

  Future<void> _cleanup(SharedPreferences preferences, DateTime now) async {
    final entries = <_StoredProgressEntry>[];
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_prefix) || key == _cleanupMarkerKey) {
        continue;
      }
      final raw = _stringOrNull(preferences, key);
      if (raw == null || raw.isEmpty) {
        await preferences.remove(key);
        continue;
      }
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final updatedAtMs = json['updatedAtMs'] as int? ?? 0;
        final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
        if (updatedAtMs <= 0 || now.difference(updatedAt) > _entryTtl) {
          await preferences.remove(key);
          continue;
        }
        entries.add(_StoredProgressEntry(key: key, updatedAt: updatedAt));
      } catch (_) {
        await preferences.remove(key);
      }
    }
    if (entries.length <= _maxEntries) {
      return;
    }
    entries.sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    final removeCount = entries.length - _maxEntries;
    for (final entry in entries.take(removeCount)) {
      await preferences.remove(entry.key);
    }
  }

  String? _stringOrNull(SharedPreferences preferences, String key) {
    try {
      return preferences.getString(key);
    } catch (_) {
      return null;
    }
  }
}

class _StoredProgressEntry {
  const _StoredProgressEntry({required this.key, required this.updatedAt});

  final String key;
  final DateTime updatedAt;
}
