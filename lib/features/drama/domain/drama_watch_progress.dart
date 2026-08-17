/// 用户在短剧列表项中的服务端观看进度。
class DramaWatchProgress {
  const DramaWatchProgress({
    required this.episodeId,
    required this.episodeNo,
    required this.positionSeconds,
    required this.progressPercent,
    required this.durationSeconds,
  });

  final String episodeId;
  final int episodeNo;
  final int positionSeconds;
  final int progressPercent;
  final int durationSeconds;

  /// 只有明确的剧集和播放位置才能作为播放器的续播提示。
  bool get canResume => episodeId != '0' && positionSeconds > 0;
}
