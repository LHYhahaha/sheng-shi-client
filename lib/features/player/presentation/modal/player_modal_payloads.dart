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

/// Recharge 大抽屉 payload（payment 确认仍在 sheet 内嵌，随 drawer 一起在 root 层展示）。
class PlayerRechargeUnlockModalPayload {
  const PlayerRechargeUnlockModalPayload({
    required this.sessionKey,
    required this.itemId,
    required this.requiredCoins,
  });

  final String sessionKey;
  final String itemId;
  final int requiredCoins;
}
