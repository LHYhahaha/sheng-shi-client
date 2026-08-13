import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/drama_playback_target.dart';

class SharedPreferencesDramaPlaybackTargetRepository
    implements DramaPlaybackTargetRepository {
  static const _prefix = 'player.drama_playback_target.';

  @override
  Future<DramaPlaybackTarget?> getForDrama(String dramaId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('$_prefix$dramaId');
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final updatedAtMs = json['updatedAtMs'] as int? ?? 0;
      final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
      if (updatedAtMs <= 0 ||
          DateTime.now().difference(updatedAt) > const Duration(days: 30)) {
        await preferences.remove('$_prefix$dramaId');
        return null;
      }
      return DramaPlaybackTarget(
        dramaId: dramaId,
        episodeId: json['episodeId'] as String? ?? '',
        episodeNo: json['episodeNo'] as int?,
        position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(DramaPlaybackTarget target) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        '$_prefix${target.dramaId}',
        jsonEncode({
          'episodeId': target.episodeId,
          if (target.episodeNo != null) 'episodeNo': target.episodeNo,
          'positionMs': target.position.inMilliseconds,
          'durationMs': target.duration.inMilliseconds,
          'updatedAtMs': target.updatedAt.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // 本地目标索引只用于优化预热，失败不能影响正常播放和原有进度持久化。
    }
  }
}
