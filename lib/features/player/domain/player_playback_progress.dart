class PlaybackProgress {
  const PlaybackProgress({
    required this.itemId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String itemId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  bool get canResume {
    if (position <= Duration.zero || duration <= Duration.zero) {
      return false;
    }
    return position < duration - const Duration(seconds: 2);
  }
}

abstract interface class PlaybackProgressRepository {
  Future<PlaybackProgress?> getProgress(String itemId);

  Future<void> saveProgress(PlaybackProgress progress);
}
