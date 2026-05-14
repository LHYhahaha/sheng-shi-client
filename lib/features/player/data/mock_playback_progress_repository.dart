import '../domain/player_playback_progress.dart';

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
