/// Entitlement 功能开关。
///
/// 这些开关让第一期 coin unlock MVP 和未来广告解锁、整剧购买、优惠券、限免等能力
/// 保持清晰边界。默认只开启金币解锁，其余全部关闭，避免 UI 或测试误以为未来能力已
/// 经具备真实服务端和风控支持。
class EntitlementFeatureConfig {
  const EntitlementFeatureConfig({
    this.enableCoinUnlock = true,
    this.enableAdUnlock = false,
    this.enableWholeDramaPurchase = false,
    this.enableCouponUnlock = false,
    this.enableLimitedFree = false,
    this.enableServerDrivenEntitlement = false,
    this.enableCrossDeviceEntitlementSync = false,
    this.enableEntitlementDebugPanel = false,
    this.enableAutoUnlockPromptRemember = false,
  });

  /// 金币单集解锁开关。
  ///
  /// 第一期开启它是为了跑通 mock entitlement 决策。真实扣费仍必须以后端权益接口为准。
  final bool enableCoinUnlock;

  /// 广告解锁预留开关，第一期关闭。
  final bool enableAdUnlock;

  /// 整剧购买预留开关，第一期关闭。
  final bool enableWholeDramaPurchase;

  /// 优惠券解锁预留开关，第一期关闭。
  final bool enableCouponUnlock;

  /// 限时免费预留开关，第一期关闭。
  final bool enableLimitedFree;

  /// 服务端驱动权益策略预留开关。
  ///
  /// 接真实 API 后服务端可能返回更复杂的 access decision；启用前不要让客户端本地
  /// 规则覆盖服务端最终判断。
  final bool enableServerDrivenEntitlement;

  /// 跨设备权益同步预留开关，第一期关闭。
  final bool enableCrossDeviceEntitlementSync;

  /// Entitlement 调试面板预留开关，第一期关闭，避免泄漏内部权益状态。
  final bool enableEntitlementDebugPanel;

  /// 自动解锁提示“记住选择”预留开关。
  final bool enableAutoUnlockPromptRemember;
}
