import '../../../../core/modal/app_modal_result.dart';

/// 解析 Membership 购买确认 [AppModalResult]。
abstract final class MembershipModalResults {
  static bool isPurchaseCompleted(AppModalResult result) {
    return result is MembershipPurchaseModalResult &&
        result.kind == AppModalResultKind.completed;
  }

  static bool isCancelled(AppModalResult result) {
    return result is MembershipPurchaseModalResult &&
        result.kind == AppModalResultKind.cancelled;
  }

  static bool isDismissed(AppModalResult result) {
    return result is MembershipPurchaseModalResult &&
        result.kind == AppModalResultKind.dismissed;
  }
}
