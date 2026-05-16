import 'package:flutter/foundation.dart';

/// 播放器性能策略模式。
enum PlayerPerformanceMode {
  /// 优先手势流畅：减少 surface 动画与跟手 transform。
  stable,

  /// 优先观感：允许跟手、渐隐与缩放反馈。
  rich,
}

/// 播放体验策略（非 UI theme token）。
///
/// 控制真实 Video surface、chrome 渐隐、转场动画等平台相关表现。
/// Android 默认 [PlayerPerformancePolicy.stable]，iOS 默认 [PlayerPerformancePolicy.rich]。
class PlayerPerformancePolicy {
  const PlayerPerformancePolicy({
    required this.mode,
    required this.allowVideoSurfaceFollowDuringDrag,
    required this.allowVideoSurfaceOpacityAnimationDuringDrag,
    required this.allowVideoSurfaceOpacityAnimationOnSettle,
    required this.allowPressChromeDimming,
    required this.allowPlayPauseScaleFeedback,
    required this.allowRichTransitions,
    this.videoSurfaceDimOpacityDuringDrag = 0.88,
  });

  /// 当前策略模式。
  final PlayerPerformanceMode mode;

  /// 拖动 PageView 时，是否让顶层真实 Video surface 跟随手指位移。
  ///
  /// Android stable 为 false：拖动只滑轻量 shell，settled 后再挂载/切换视频。
  final bool allowVideoSurfaceFollowDuringDrag;

  /// 拖动过程中，是否对真实 Video surface 做 opacity 动画/压暗。
  ///
  /// Android stable 为 false，避免 native surface 合成开销。
  final bool allowVideoSurfaceOpacityAnimationDuringDrag;

  /// 落位后，是否对 Video surface 做 opacity 过渡动画。
  ///
  /// Android stable 为 false，落位后直接显示。
  final bool allowVideoSurfaceOpacityAnimationOnSettle;

  /// 按压播放区域时，是否让非视频 chrome（顶栏/文案/按钮区）渐隐。
  ///
  /// Android stable 为 false。
  final bool allowPressChromeDimming;

  /// 点击暂停时，是否显示 transient 缩放反馈动画。
  ///
  /// Android stable 为 false。
  final bool allowPlayPauseScaleFeedback;

  /// 是否启用 richer 转场（预留综合开关，供后续扩展）。
  final bool allowRichTransitions;

  /// rich 模式下拖动时 Video surface 的目标 opacity（仅当允许拖动 opacity 时生效）。
  final double videoSurfaceDimOpacityDuringDrag;

  /// Android 设备默认 stable 策略。
  static const stable = PlayerPerformancePolicy(
    mode: PlayerPerformanceMode.stable,
    allowVideoSurfaceFollowDuringDrag: false,
    allowVideoSurfaceOpacityAnimationDuringDrag: false,
    allowVideoSurfaceOpacityAnimationOnSettle: false,
    allowPressChromeDimming: false,
    allowPlayPauseScaleFeedback: false,
    allowRichTransitions: false,
  );

  /// iOS 设备默认 rich 策略。
  static const rich = PlayerPerformancePolicy(
    mode: PlayerPerformanceMode.rich,
    allowVideoSurfaceFollowDuringDrag: true,
    allowVideoSurfaceOpacityAnimationDuringDrag: true,
    allowVideoSurfaceOpacityAnimationOnSettle: true,
    allowPressChromeDimming: true,
    allowPlayPauseScaleFeedback: true,
    allowRichTransitions: true,
  );

  /// 按 [TargetPlatform] 选择默认策略。
  static PlayerPerformancePolicy forPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => stable,
      _ => rich,
    };
  }

  bool get isStable => mode == PlayerPerformanceMode.stable;

  bool get isRich => mode == PlayerPerformanceMode.rich;
}
