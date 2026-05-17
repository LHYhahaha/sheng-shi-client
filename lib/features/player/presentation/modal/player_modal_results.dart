import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import 'player_modal_channels.dart';

/// 解析 Player 相关 [AppModalResult]。
abstract final class PlayerModalResults {
  static bool isUnlocked(AppModalResult result) {
    return result is CoinUnlockModalResult &&
        result.kind == AppModalResultKind.completed;
  }

  static bool isRechargeSuccess(AppModalResult result) {
    return result is RechargeModalResult &&
        result.kind == AppModalResultKind.completed;
  }

  static bool isPaymentCompleted(AppModalResult result) {
    return result is PaymentModalResult &&
        result.kind == AppModalResultKind.completed;
  }

  static bool isDismissed(AppModalResult result) {
    return result.kind == AppModalResultKind.dismissed;
  }

  static bool isCancelled(AppModalResult result) {
    return result.kind == AppModalResultKind.cancelled;
  }
}

extension PlayerFeatureAppModalRequestX on FeatureAppModalRequest {
  bool get isPlayerCoinUnlock => channel == PlayerModalChannels.coinUnlock;

  bool get isPlayerRechargeUnlock =>
      channel == PlayerModalChannels.rechargeUnlock;

  bool get isPlayerPaymentMethod =>
      channel == PlayerModalChannels.paymentMethod;
}
