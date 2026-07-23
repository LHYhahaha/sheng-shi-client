import 'package:flutter/foundation.dart';

import 'player_preload_config.dart';

/// 播放器性能策略档位。
enum PlayerPerformanceMode {
  /// 优先观感：跟手、渐隐、缩放反馈（典型 iOS / 高性能设备）。
  rich,

  /// 普通 Android 默认：手势优先，减少 surface 动画。
  stable,

  /// 低端 Android：在 stable 基础上进一步收敛 HLS 与 media session 窗口。
  ultraStable,
}

/// 播放体验与相邻预热策略（非 UI theme token）。
///
/// - 视觉类字段：控制 Video surface、chrome、转场。
/// - 预热类字段：控制 HLS HTTP 预取与 media session 窗口（见各字段注释）。
///
/// 平台默认：Android [stable]，iOS [rich]。低端机通过 provider override 为 [ultraStable]。
class PlayerPerformancePolicy {
  const PlayerPerformancePolicy({
    required this.mode,
    required this.allowVideoSurfaceVisibleDuringDrag,
    required this.allowVideoSurfaceFollowDuringDrag,
    required this.allowVideoSurfaceOpacityAnimationDuringDrag,
    required this.allowVideoSurfaceOpacityAnimationOnSettle,
    required this.allowPressChromeDimming,
    required this.allowPlayPauseScaleFeedback,
    required this.allowRichTransitions,
    required this.homeStartupHlsPreloadCount,
    required this.singleDramaForwardHlsPreloadCount,
    required this.singleDramaBackwardHlsPreloadCount,
    required this.forYouForwardHlsPreloadCount,
    required this.forYouBackwardHlsPreloadCount,
    required this.preparedForwardSessionCount,
    required this.retainedBackwardSessionCount,
    required this.skipPreloadWhenCurrentItemLocked,
    required this.allowSeekThumbnailPreview,
    required this.allowSeekTimeBubble,
    required this.allowSeekPreviewShadow,
    this.videoSurfaceDimOpacityDuringDrag = 0.88,
  });

  /// 当前策略档位。
  final PlayerPerformanceMode mode;

  /// 拖动 PageView 时，是否保持顶层真实 Video surface 可见（不黑屏）。
  ///
  /// 影响：仅 UI。关闭时拖动期间隐藏 surface，优先滑动流畅（典型 ultraStable）。
  /// 与 [allowVideoSurfaceFollowDuringDrag] 独立：可见 ≠ 跟手 transform。
  final bool allowVideoSurfaceVisibleDuringDrag;

  /// 拖动 PageView 时，是否让顶层真实 Video surface 跟随手指位移。
  ///
  /// 影响：仅 UI 合成。需 [allowVideoSurfaceVisibleDuringDrag] 为 true 才有意义；
  /// 开启可提升跟手感；stable 常仅保留画面、不跟手。
  final bool allowVideoSurfaceFollowDuringDrag;

  /// 拖动过程中，是否对真实 Video surface 做 opacity 动画/压暗。
  ///
  /// 影响：仅 UI。开启会增加 native surface 合成成本。
  final bool allowVideoSurfaceOpacityAnimationDuringDrag;

  /// 落位后，是否对 Video surface 做 opacity 过渡动画。
  ///
  /// 影响：仅 UI。关闭可让落位后立刻显示，减少动画帧。
  final bool allowVideoSurfaceOpacityAnimationOnSettle;

  /// 按压播放区域时，是否让非视频 chrome（顶栏/文案/按钮区）渐隐。
  ///
  /// 影响：仅 UI。关闭可减少 overlay 重绘与 AnimatedOpacity。
  final bool allowPressChromeDimming;

  /// 点击暂停时，是否显示 transient 缩放反馈动画。
  ///
  /// 影响：仅 UI。
  final bool allowPlayPauseScaleFeedback;

  /// 是否启用 richer 转场（预留综合开关）。
  ///
  /// 影响：仅 UI / 轻量 shell 动效，不扩大 media session 窗口。
  final bool allowRichTransitions;

  /// 首页启动阶段 HLS HTTP 预加载条数（playlist/segment 请求，不持有播放器实例）。
  ///
  /// 增大：首页可能更快进入首帧，但会与列表渲染抢带宽。
  /// 风险：弱网下浪费流量；与 media session 无关。
  final int homeStartupHlsPreloadCount;

  /// 单剧 feed 向后 HLS HTTP 预加载条数（仅网络预热，非 media prepare）。
  ///
  /// 增大：向下滑下一集可能减少等待；快速滑走时可能浪费带宽。
  /// 风险：与当前播放抢 CDN/解码器准备时间；不自动扩大 prepared session。
  final int singleDramaForwardHlsPreloadCount;

  /// 单剧 feed 向前 HLS HTTP 预加载条数。
  ///
  /// 增大：回滑上一集可能略快；连续上滑收益有限。
  /// 风险：额外 HTTP；回滑主路径仍依赖 retained media session。
  final int singleDramaBackwardHlsPreloadCount;

  /// For You 向后 HLS HTTP 预加载条数。
  final int forYouForwardHlsPreloadCount;

  /// For You 向前 HLS HTTP 预加载条数。
  final int forYouBackwardHlsPreloadCount;

  /// 向后 media-session prepare 数量（持有 Player + 解码器，cap 0..1）。
  ///
  /// 增大：下一集接管可能更快。
  /// 风险：多实例并存、音频焦点与后台释放复杂度上升；客户端禁止 >1。
  final int preparedForwardSessionCount;

  /// 向前 retained media-session 数量（cap 0..1）。
  ///
  /// 增大：回滑恢复进度可能更快。
  /// 风险：额外解码器与内存；客户端禁止 >1。
  final int retainedBackwardSessionCount;

  /// 当前落位项为 locked 时，是否跳过 settled 后的 preloadAround / prepare。
  ///
  /// ultraStable 为 true：付费集落位后不做相邻 HLS 与 next prepare，减轻低端机压力。
  final bool skipPreloadWhenCurrentItemLocked;

  /// rich 模式拖动时 Video surface 压暗 opacity。
  final double videoSurfaceDimOpacityDuringDrag;

  /// 拖动进度条时是否显示海报缩略图预览（单剧 seek）。
  ///
  /// 开启会绘制 Image + 圆角卡片；服务端 sprite/VTT 未来也受此门控。
  final bool allowSeekThumbnailPreview;

  /// 拖动进度条时是否显示轻量时间气泡（无图）。
  ///
  /// ultraStable 关闭时仅加粗轨道，减少阴影/渐变/文案重绘。
  final bool allowSeekTimeBubble;

  /// 缩略图预览是否使用阴影与底部渐变（仅 thumbnail 开启时生效）。
  final bool allowSeekPreviewShadow;

  /// iOS / 高性能默认可视策略；HLS/session 与 stable 同级（仍为保守 cap）。
  static const rich = PlayerPerformancePolicy(
    mode: PlayerPerformanceMode.rich,
    allowVideoSurfaceVisibleDuringDrag: true,
    allowVideoSurfaceFollowDuringDrag: true,
    allowVideoSurfaceOpacityAnimationDuringDrag: true,
    allowVideoSurfaceOpacityAnimationOnSettle: true,
    allowPressChromeDimming: true,
    allowPlayPauseScaleFeedback: true,
    allowRichTransitions: true,
    homeStartupHlsPreloadCount: 1,
    singleDramaForwardHlsPreloadCount: 1,
    singleDramaBackwardHlsPreloadCount: 1,
    forYouForwardHlsPreloadCount: 1,
    forYouBackwardHlsPreloadCount: 1,
    preparedForwardSessionCount: 1,
    retainedBackwardSessionCount: 1,
    skipPreloadWhenCurrentItemLocked: false,
    allowSeekThumbnailPreview: true,
    allowSeekTimeBubble: true,
    allowSeekPreviewShadow: true,
  );

  /// 普通 Android 默认。
  static const stable = PlayerPerformancePolicy(
    mode: PlayerPerformanceMode.stable,
    allowVideoSurfaceVisibleDuringDrag: true,
    allowVideoSurfaceFollowDuringDrag: true,
    allowVideoSurfaceOpacityAnimationDuringDrag: false,
    allowVideoSurfaceOpacityAnimationOnSettle: false,
    allowPressChromeDimming: false,
    allowPlayPauseScaleFeedback: false,
    allowRichTransitions: false,
    homeStartupHlsPreloadCount: 1,
    singleDramaForwardHlsPreloadCount: 1,
    singleDramaBackwardHlsPreloadCount: 1,
    forYouForwardHlsPreloadCount: 1,
    forYouBackwardHlsPreloadCount: 1,
    preparedForwardSessionCount: 1,
    retainedBackwardSessionCount: 1,
    skipPreloadWhenCurrentItemLocked: false,
    allowSeekThumbnailPreview: false,
    allowSeekTimeBubble: true,
    allowSeekPreviewShadow: false,
  );

  /// 低端 Android：视觉同 stable，HLS/session 更保守。
  static const ultraStable = PlayerPerformancePolicy(
    mode: PlayerPerformanceMode.ultraStable,
    allowVideoSurfaceVisibleDuringDrag: false,
    allowVideoSurfaceFollowDuringDrag: false,
    allowVideoSurfaceOpacityAnimationDuringDrag: false,
    allowVideoSurfaceOpacityAnimationOnSettle: false,
    allowPressChromeDimming: false,
    allowPlayPauseScaleFeedback: false,
    allowRichTransitions: false,
    homeStartupHlsPreloadCount: 0,
    singleDramaForwardHlsPreloadCount: 0,
    singleDramaBackwardHlsPreloadCount: 0,
    forYouForwardHlsPreloadCount: 0,
    forYouBackwardHlsPreloadCount: 0,
    preparedForwardSessionCount: 0,
    retainedBackwardSessionCount: 0,
    skipPreloadWhenCurrentItemLocked: true,
    allowSeekThumbnailPreview: false,
    allowSeekTimeBubble: false,
    allowSeekPreviewShadow: false,
  );

  /// 按平台选择默认档位（不含低端机识别；低端机请 override [ultraStable]）。
  static PlayerPerformancePolicy forPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => stable,
      _ => rich,
    };
  }

  /// 按档位选择完整策略（供远程配置 / 设备分级预留）。
  static PlayerPerformancePolicy forMode(PlayerPerformanceMode mode) {
    return switch (mode) {
      PlayerPerformanceMode.rich => rich,
      PlayerPerformanceMode.stable => stable,
      PlayerPerformanceMode.ultraStable => ultraStable,
    };
  }

  bool get isRich => mode == PlayerPerformanceMode.rich;

  bool get isStable => mode == PlayerPerformanceMode.stable;

  bool get isUltraStable => mode == PlayerPerformanceMode.ultraStable;

  /// 转为 [PlayerPreloadConfig]，供 HLS preloader 与 playback controller 读取。
  PlayerPreloadConfig toPreloadConfig() {
    return PlayerPreloadConfig(
      homeStartupPreloadCount: homeStartupHlsPreloadCount,
      singleDramaForwardHlsPreloadCount: singleDramaForwardHlsPreloadCount,
      singleDramaBackwardHlsPreloadCount: singleDramaBackwardHlsPreloadCount,
      forYouForwardHlsPreloadCount: forYouForwardHlsPreloadCount,
      forYouBackwardHlsPreloadCount: forYouBackwardHlsPreloadCount,
      preparedForwardSessionCount: preparedForwardSessionCount,
      retainedBackwardSessionCount: retainedBackwardSessionCount,
    );
  }
}
