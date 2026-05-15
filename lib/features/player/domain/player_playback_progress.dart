/// 单剧播放进度。
///
/// 当前只在 single drama session 保存进度，For You 信息流不持久化。不要把这个模型
/// 用作实时播放位置源，实时位置仍来自 media session stream。
class PlaybackProgress {
  const PlaybackProgress({
    required this.itemId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  /// 进度对应的 feed item id。
  ///
  /// 当前只保存单剧 item，For You 不持久化，避免信息流滑动污染追剧进度。
  final String itemId;

  /// 已播放位置。
  ///
  /// 只用于恢复播放，不作为当前实时 position；实时位置来自播放器 stream。
  final Duration position;

  /// 保存时的媒体总时长。
  ///
  /// 用于判断进度是否接近结尾，接近结尾不再恢复，避免打开即结束。
  final Duration duration;

  /// 进度更新时间。
  ///
  /// 未来服务端同步可用它做冲突解决；当前内存实现只用于诊断。
  final DateTime updatedAt;

  bool get canResume {
    if (position <= Duration.zero || duration <= Duration.zero) {
      return false;
    }
    return position < duration - const Duration(seconds: 2);
  }
}

/// 播放进度仓库边界。
///
/// 只保存可恢复进度，不参与当前播放状态。真实接入时需要节流/去重，避免 position
/// stream 高频写接口。
abstract interface class PlaybackProgressRepository {
  Future<PlaybackProgress?> getProgress(String itemId);

  Future<void> saveProgress(PlaybackProgress progress);
}
