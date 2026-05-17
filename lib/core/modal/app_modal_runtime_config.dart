/// 全局弹窗运行时配置（本地默认；真实 remote kill switch 后续再接）。
class AppModalRuntimeConfig {
  const AppModalRuntimeConfig({
    this.enableGlobalModalSystem = true,
    this.enableModalDiagnostics = false,
    this.maxQueueLength = 5,
    this.allowPreemption = false,
  });

  static const defaults = AppModalRuntimeConfig();

  /// 关闭时 [AppModalController] 立即返回 [AppModalRejectedResult]，不展示 UI。
  /// 生产默认 true；仅测试 / 文档验证 override。
  final bool enableGlobalModalSystem;

  /// 为 true 时 [AppModalObserver] 应记录事件（默认 no-op observer）。
  final bool enableModalDiagnostics;

  /// 当前 modal 展示中时，允许排队的最大 pending 数（不含 current）。
  final int maxQueueLength;

  /// 高优先级是否抢占 current。O5 默认 false，仅预留策略位。
  final bool allowPreemption;

  AppModalRuntimeConfig copyWith({
    bool? enableGlobalModalSystem,
    bool? enableModalDiagnostics,
    int? maxQueueLength,
    bool? allowPreemption,
  }) {
    return AppModalRuntimeConfig(
      enableGlobalModalSystem:
          enableGlobalModalSystem ?? this.enableGlobalModalSystem,
      enableModalDiagnostics:
          enableModalDiagnostics ?? this.enableModalDiagnostics,
      maxQueueLength: maxQueueLength ?? this.maxQueueLength,
      allowPreemption: allowPreemption ?? this.allowPreemption,
    );
  }
}
