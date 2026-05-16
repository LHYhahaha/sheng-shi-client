import 'player_performance_policy.dart';

/// 单剧进度条拖动预览配置（由 [PlayerPerformancePolicy] 派生，集中收口）。
///
/// 未来服务端 preview sprite / VTT 仅在 [allowThumbnailPreview] 为 true 时考虑接入。
class PlayerSeekPreviewConfig {
  const PlayerSeekPreviewConfig({
    required this.allowThumbnailPreview,
    required this.allowTimeBubble,
    required this.allowPreviewShadow,
  });

  /// 拖动时是否显示海报/缩略图卡片预览。
  ///
  /// rich 为 true；会增加 Image + 圆角容器绘制。低端机关闭以减轻拖动重绘。
  final bool allowThumbnailPreview;

  /// 拖动时是否显示轻量时间文本（无图）。
  ///
  /// stable 可 true；ultraStable 为 false 时仅加粗轨道，无浮动文案。
  final bool allowTimeBubble;

  /// 缩略图预览是否使用阴影/渐变等重视觉（仅 [allowThumbnailPreview] 时有效）。
  ///
  /// rich 为 true；减少 stable 误开 thumbnail 时的合成成本。
  final bool allowPreviewShadow;

  factory PlayerSeekPreviewConfig.fromPolicy(PlayerPerformancePolicy policy) {
    return PlayerSeekPreviewConfig(
      allowThumbnailPreview: policy.allowSeekThumbnailPreview,
      allowTimeBubble: policy.allowSeekTimeBubble,
      allowPreviewShadow: policy.allowSeekPreviewShadow,
    );
  }
}
