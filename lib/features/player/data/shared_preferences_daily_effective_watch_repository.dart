import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/daily_effective_watch.dart';

final dailyEffectiveWatchRepositoryProvider =
    Provider<DailyEffectiveWatchRepository>(
      (ref) => SharedPreferencesDailyEffectiveWatchRepository(),
    );

class SharedPreferencesDailyEffectiveWatchRepository
    implements DailyEffectiveWatchRepository {
  static const _prefix = 'player.daily_effective_watch.v1.';
  String _key(String userId, String day) =>
      '$_prefix${Uri.encodeComponent(userId)}.$day';

  @override
  Future<DailyEffectiveWatchSnapshot?> read(
    String userId,
    String dayKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key(userId, dayKey));
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final total = (json['creditedMs'] as num).toDouble();
      if (json['version'] != 1 ||
          json['userId'] != userId ||
          json['dayKey'] != dayKey ||
          json['dayPolicy'] != 'india-ist-v1' ||
          !total.isFinite ||
          total < 0) {
        throw const FormatException('Invalid ledger');
      }
      final ranges = <String, List<WatchedRange>>{};
      for (final entry in (json['ranges'] as Map<String, dynamic>).entries) {
        final ids = jsonDecode(entry.key) as List<dynamic>;
        if (ids.length != 2 || ids.any((id) => id is! String || id.isEmpty)) {
          throw const FormatException('Invalid episode identity');
        }
        var previousEnd = -1;
        ranges[entry.key] = [
          for (final raw in entry.value as List<dynamic>)
            (() {
              final pair = raw as List<dynamic>;
              if (pair.length != 2) {
                throw const FormatException('Invalid range');
              }
              final start = pair[0] as int;
              final end = pair[1] as int;
              if (start < 0 || start <= previousEnd || end <= start) {
                throw const FormatException('Invalid range');
              }
              previousEnd = end;
              return WatchedRange(start, end);
            })(),
        ];
      }
      return DailyEffectiveWatchSnapshot(
        userId: userId,
        dayKey: dayKey,
        creditedMs: total,
        ranges: ranges,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(DailyEffectiveWatchSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      _key(snapshot.userId, snapshot.dayKey),
      jsonEncode({
        'version': 1,
        'dayPolicy': 'india-ist-v1',
        'userId': snapshot.userId,
        'dayKey': snapshot.dayKey,
        'creditedMs': snapshot.creditedMs,
        'ranges': {
          for (final entry in snapshot.ranges.entries)
            entry.key: [
              for (final range in entry.value) [range.startMs, range.endMs],
            ],
        },
      }),
    );
    if (!saved) throw StateError('Failed to save effective watch time');
    // Retain seven India dates; never evict an episode from today's ledger.
    final cutoff = DateTime.parse(
      '${snapshot.dayKey}T00:00:00Z',
    ).subtract(const Duration(days: 6));
    final userPrefix = '$_prefix${Uri.encodeComponent(snapshot.userId)}.';
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
