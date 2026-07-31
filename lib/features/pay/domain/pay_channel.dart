/// 服务端下发的支付渠道枚举。
abstract final class PayChannel {
  static const google = 'PAY_CHANNEL_GOOGLE';
  static const apple = 'PAY_CHANNEL_APPLE';
  static const other = 'PAY_CHANNEL_OTHER';

  /// 历史商品可能尚未下发 `payChannel`；这类商品沿用原有 Google IAP 逻辑。
  static bool isGoogle(String? value) {
    final normalized = value?.trim();
    return normalized == null ||
        normalized.isEmpty ||
        normalized == 'null' ||
        normalized == google;
  }

  static bool isApple(String? value) => value?.trim() == apple;
  static bool isOther(String? value) => value?.trim() == other;
}
