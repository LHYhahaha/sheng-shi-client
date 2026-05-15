import '../domain/player_playback_progress.dart';

/// 内存版播放进度仓库。
///
/// 仅用于 MVP 和测试，应用重启会丢失。接真实存储时仍应保持相同接口，避免播放控制器
/// 直接依赖 SharedPreferences/数据库。
class InMemoryPlaybackProgressRepository implements PlaybackProgressRepository {
  final _progressByItemId = <String, PlaybackProgress>{};

  @override
  Future<PlaybackProgress?> getProgress(String itemId) async {
    return _progressByItemId[itemId];
  }

  @override
  Future<void> saveProgress(PlaybackProgress progress) async {
    _progressByItemId[progress.itemId] = progress;
  }
}
