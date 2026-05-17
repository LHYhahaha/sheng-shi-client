/// 弹窗优先级；O5 将用于队列抢占。
enum AppModalPriority { low, normal, high, critical }

/// 弹窗关闭策略。
class AppModalDismissPolicy {
  const AppModalDismissPolicy({
    this.barrierDismissible = true,
    this.backButtonAllowed = true,
    this.requiresExplicitChoice = false,
  });

  /// 点击遮罩是否可关闭。
  final bool barrierDismissible;

  /// Android 返回键是否可关闭。
  final bool backButtonAllowed;

  /// 是否必须点确认/取消之一（禁止遮罩/返回静默关闭）。
  final bool requiresExplicitChoice;

  static const AppModalDismissPolicy standard = AppModalDismissPolicy();

  static const AppModalDismissPolicy blocking = AppModalDismissPolicy(
    barrierDismissible: false,
    backButtonAllowed: false,
    requiresExplicitChoice: true,
  );
}
