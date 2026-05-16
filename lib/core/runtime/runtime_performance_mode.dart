/// 全局运行时播放器性能档位（feature-neutral）。
///
/// 由 [RuntimePlayerConfig] 与设备档位推导使用；播放器 feature 在 application
/// 层映射为自有 domain policy（见 `runtime_performance_mode_mapper.dart`）。
enum RuntimePerformanceMode {
  /// 优先观感：跟手、渐隐、缩放反馈（典型 iOS / 高性能设备）。
  rich,

  /// 普通 Android 默认：手势优先，减少 surface 动画。
  stable,

  /// 低端机：收敛 HLS 预加载与 prepared/retained session 窗口。
  ultraStable,
}
