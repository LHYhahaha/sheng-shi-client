import '../widgets/player_payment_method_sheet.dart';

/// Coin unlock 弹窗 payload。
class PlayerCoinUnlockModalPayload {
  const PlayerCoinUnlockModalPayload({
    required this.sessionKey,
    required this.itemId,
    required this.price,
  });

  final String sessionKey;
  final String itemId;
  final int price;
}

/// Payment Method 叠层 payload（O2.1：stackOnCurrent 于充值大抽屉之上）。
class PlayerPaymentMethodModalPayload {
  const PlayerPaymentMethodModalPayload({
    required this.sessionKey,
    required this.selection,
  });

  final String sessionKey;
  final PlayerPaymentSelection selection;
}

/// Recharge 大抽屉 payload。
class PlayerRechargeUnlockModalPayload {
  const PlayerRechargeUnlockModalPayload({
    required this.sessionKey,
    required this.itemId,
    required this.requiredCoins,
    required this.dramaId,
    required this.episodeNo,
    required this.shortTitle,
    required this.cover,
    required this.episodeId,
  });

  final String sessionKey;
  final String itemId;
  final int requiredCoins;
  final int dramaId;
  final int episodeNo;
  final String shortTitle;
  final String cover;
  final int episodeId;
}
