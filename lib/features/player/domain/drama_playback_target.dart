/// 某部剧最近一次可恢复的本地播放目标。
///
/// 它与按 itemId 保存的 [PlaybackProgress] 并存：后者用于播放器精确恢复，
/// 这个轻量索引让首页在拿到 dramaId 时即可选中要预热的集与位置，无需等待服务端
/// 观看记录接口。
class DramaPlaybackTarget {
  const DramaPlaybackTarget({
    required this.dramaId,
    required this.episodeId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String dramaId;
  final String episodeId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  bool get canResume =>
      position > Duration.zero &&
      duration > Duration.zero &&
      position < duration - const Duration(seconds: 2);
}

abstract interface class DramaPlaybackTargetRepository {
  Future<DramaPlaybackTarget?> getForDrama(String dramaId);

  Future<void> save(DramaPlaybackTarget target);
}
