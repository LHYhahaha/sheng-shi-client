import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'hls_disk_cache_store.dart';

/// Small, non-sensitive performance profile for an HLS source.
///
/// The key removes signed URL parameters; no access token or full signed URL
/// is persisted. Profiles guide preload policy only and never authorize media.
class HlsSourceProfile {
  const HlsSourceProfile({
    required this.key,
    required this.renditionCount,
    required this.sourceRenditionCount,
    required this.fellBackAboveMaxHeight,
    required this.isSingleRendition,
    required this.firstSegmentBytes,
    required this.firstSegmentElapsedMs,
    required this.updatedAtMs,
  });

  final String key;
  final int renditionCount;
  final int sourceRenditionCount;
  final bool fellBackAboveMaxHeight;
  final bool isSingleRendition;
  final int firstSegmentBytes;
  final int firstSegmentElapsedMs;
  final int updatedAtMs;

  Map<String, Object> toJson() => {
    'r': renditionCount,
    'o': sourceRenditionCount,
    'f': fellBackAboveMaxHeight,
    's': isSingleRendition,
    'b': firstSegmentBytes,
    'e': firstSegmentElapsedMs,
    'u': updatedAtMs,
  };

  static HlsSourceProfile? fromJson(String key, Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final updatedAtMs = value['u'];
    if (updatedAtMs is! int) return null;
    return HlsSourceProfile(
      key: key,
      renditionCount: (value['r'] as int?) ?? 1,
      sourceRenditionCount: (value['o'] as int?) ?? (value['r'] as int?) ?? 1,
      fellBackAboveMaxHeight: (value['f'] as bool?) ?? false,
      isSingleRendition: (value['s'] as bool?) ?? true,
      firstSegmentBytes: (value['b'] as int?) ?? 0,
      firstSegmentElapsedMs: (value['e'] as int?) ?? 0,
      updatedAtMs: updatedAtMs,
    );
  }
}

abstract interface class HlsSourceProfileStore {
  Future<void> record(HlsSourceProfile profile);
}

class SharedPreferencesHlsSourceProfileStore implements HlsSourceProfileStore {
  static const _storageKey = 'player_hls_source_profiles_v1';
  static const _maxEntries = 120;
  static const _maxAge = Duration(days: 14);
  Future<void> _tail = Future<void>.value();

  @override
  Future<void> record(HlsSourceProfile profile) {
    final operation = _tail.then((_) => _record(profile));
    _tail = operation.catchError((_) {});
    return operation;
  }

  Future<void> _record(HlsSourceProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final decoded = raw == null ? <String, dynamic>{} : jsonDecode(raw);
      final entries = decoded is Map<String, dynamic>
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      final now = DateTime.now().millisecondsSinceEpoch;
      entries.removeWhere((_, value) {
        final existing = HlsSourceProfile.fromJson('', value);
        return existing == null ||
            now - existing.updatedAtMs > _maxAge.inMilliseconds;
      });
      entries[profile.key] = profile.toJson();
      if (entries.length > _maxEntries) {
        final oldest = entries.entries.toList()
          ..sort((a, b) {
            final left =
                HlsSourceProfile.fromJson('', a.value)?.updatedAtMs ?? 0;
            final right =
                HlsSourceProfile.fromJson('', b.value)?.updatedAtMs ?? 0;
            return left.compareTo(right);
          });
        for (final entry in oldest.take(entries.length - _maxEntries)) {
          entries.remove(entry.key);
        }
      }
      await prefs.setString(_storageKey, jsonEncode(entries));
    } catch (_) {
      // Profiling must never delay or fail playback.
    }
  }

  static String stableKeyForSource(String sourceUrl) {
    final outer = Uri.tryParse(sourceUrl);
    final embedded = outer?.queryParameters['url'];
    final inner = embedded == null ? null : Uri.tryParse(embedded);
    return HlsDiskCacheStore.keyForUri(inner ?? outer ?? Uri());
  }
}
