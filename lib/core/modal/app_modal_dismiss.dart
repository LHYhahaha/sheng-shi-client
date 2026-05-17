import 'app_modal_policy.dart';

/// 是否允许点击遮罩关闭。
bool appModalBarrierDismissible(AppModalDismissPolicy policy) {
  return policy.barrierDismissible && !policy.requiresExplicitChoice;
}

/// 是否允许系统返回键关闭（Android back / iOS 手势由 PopScope 处理）。
bool appModalBackButtonAllowed(AppModalDismissPolicy policy) {
  return policy.backButtonAllowed && !policy.requiresExplicitChoice;
}
