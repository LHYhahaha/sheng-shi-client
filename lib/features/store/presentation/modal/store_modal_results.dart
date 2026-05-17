import '../../../../core/modal/app_modal_result.dart';

/// 解析 Store 购买确认 [AppModalResult]。
abstract final class StoreModalResults {
  static bool isPurchaseCompleted(AppModalResult result) {
    return result is StorePurchaseModalResult &&
        result.kind == AppModalResultKind.completed;
  }

  static bool isCancelled(AppModalResult result) {
    return result is StorePurchaseModalResult &&
        result.kind == AppModalResultKind.cancelled;
  }

  static bool isDismissed(AppModalResult result) {
    return result is StorePurchaseModalResult &&
        result.kind == AppModalResultKind.dismissed;
  }
}
