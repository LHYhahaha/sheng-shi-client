/// 福利中心中当前仍可领取的奖励金币。
///
/// 服务端使用 int64 数值字符串，客户端保留原字符串以避免大数精度丢失。
class RewardCoinRemaining {
  const RewardCoinRemaining({required this.value});

  final String value;

  bool get isPositive => (BigInt.tryParse(value) ?? BigInt.zero) > BigInt.zero;
}
