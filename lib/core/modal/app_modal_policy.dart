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

  /// 阻塞式：不可点遮罩关闭；返回键可关闭（与 standard 体验区分）。
  static const AppModalDismissPolicy blocking = AppModalDismissPolicy(
    barrierDismissible: false,
    backButtonAllowed: true,
    requiresExplicitChoice: false,
  );

  /// 不可通过遮罩/返回关闭，仅明确按钮或 dismiss API。
  static const AppModalDismissPolicy nonDismissible = AppModalDismissPolicy(
    barrierDismissible: false,
    backButtonAllowed: false,
    requiresExplicitChoice: true,
  );

  /// 与 [nonDismissible] 相同，用于强更/风控等关键弹窗预留。
  static const AppModalDismissPolicy critical = nonDismissible;
}
