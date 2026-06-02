/// 观看进度上报 DTO。
class WatchProgressReportDto {
  const WatchProgressReportDto({
    required this.autoUnlockNext,
    required this.dramaId,
    required this.durationSecond,
    required this.episodeId,
    required this.episodeNo,
    required this.eventType,
    required this.watchSecond,
  });

  /// 是否触发自动解锁下一集。
  final bool autoUnlockNext;

  /// 短剧 ID。
  final int dramaId;

  /// 视频总时长（秒）。
  final int durationSecond;

  /// 分集 ID（可选）。
  final int? episodeId;

  /// 集数。
  final int episodeNo;

  /// 播放事件类型：1开始，2进度，3暂停，4退出，5切集，6完成。
  final int eventType;

  /// 观看到第几秒。
  final int watchSecond;

  Map<String, Object?> toJson() {
    return {
      'autoUnlockNext': autoUnlockNext,
      'dramaId': dramaId,
      'durationSecond': durationSecond,
      'episodeId': episodeId,
      'episodeNo': episodeNo,
      'eventType': eventType,
      'watchSecond': watchSecond,
    };
  }
}

/// 观看进度上报事件类型。
abstract final class WatchProgressEventType {
  static const int start = 1;
  static const int progress = 2;
  static const int pause = 3;
  static const int exit = 4;
  static const int switchEpisode = 5;
  static const int complete = 6;
}
