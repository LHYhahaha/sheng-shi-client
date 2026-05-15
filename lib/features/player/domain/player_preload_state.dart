/// HLS preload 的阶段状态。
///
/// pending/success/failed/cancelled 只描述 HTTP 预热，不描述播放器是否可播放。
enum PlaybackPreloadStatus { pending, success, failed, cancelled }

/// 单个 item 的 HLS 预热状态。
///
/// 这个状态用于 UI/测试观测和 timing trace；不要用 success 直接跳过播放时的
/// source resolve/open，因为签名 URL 仍可能过期或被权限策略拒绝。
class PlaybackPreloadState {
  const PlaybackPreloadState({
    required this.itemId,
    required this.sourceUrl,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.error,
    this.details,
  });

  /// 预热对应的 feed item id。
  final String itemId;

  /// 预热时使用的 source URL。
  ///
  /// 可能是 remote URL 或经过 proxy resolver 的 playable source，用于诊断实际预热路径。
  final String sourceUrl;

  /// 预热阶段状态。
  ///
  /// success 只说明 HTTP 预热完成，不说明 media session 已打开。
  final PlaybackPreloadStatus status;

  /// 预热开始时间。
  ///
  /// 用于计算 HLS preload 耗时和判断 pending 是否过期。
  final DateTime startedAt;

  /// 预热结束时间。
  ///
  /// pending 时为空。cancelled/failed/success 都应填入，方便排查释放时机。
  final DateTime? completedAt;

  /// 预热错误。
  ///
  /// 只用于诊断；预热失败不应直接让当前播放进入 error。
  final Object? error;

  /// HLS 预热诊断信息。
  ///
  /// 例如 playlist/segment 拉取摘要，不能作为业务判断条件。
  final String? details;

  PlaybackPreloadState copyWith({
    PlaybackPreloadStatus? status,
    DateTime? completedAt,
    Object? error,
    String? details,
    bool clearError = false,
    bool clearDetails = false,
  }) {
    return PlaybackPreloadState(
      itemId: itemId,
      sourceUrl: sourceUrl,
      status: status ?? this.status,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: clearError ? null : error ?? this.error,
      details: clearDetails ? null : details ?? this.details,
    );
  }
}

/// 预留的 pending preload 描述。
///
/// 用于把异步任务和 item/source 绑定在一起。释放 pending 时必须通过 generation 或
/// manager release 失效，不能只从列表移除 UI 状态。
class PendingPreload {
  const PendingPreload({
    required this.itemId,
    required this.sourceUrl,
    required this.generation,
  });

  /// pending 任务对应 item id。
  final String itemId;

  /// pending 任务对应 source。
  final String sourceUrl;

  /// 创建 pending 时的 generation。
  ///
  /// release/cancel 后 generation 变化，旧任务返回时必须被忽略。
  final int generation;
}
