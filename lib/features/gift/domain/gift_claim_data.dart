/// 赠送权益领取成功后的服务端结果。
class GiftClaimData {
  const GiftClaimData({
    required this.benefitDays,
    required this.dramaId,
    required this.giftType,
    required this.isAvailable,
    required this.reason,
    required this.reasonCode,
    required this.shareCode,
  });

  final int benefitDays;
  final String dramaId;

  /// 1=短剧，2=临时会员。
  final int giftType;
  final bool isAvailable;
  final String reason;
  final int reasonCode;
  final String shareCode;

  bool get isDrama => giftType == 1;
  bool get isTemporaryVip => giftType == 2;

  /// 领取接口以 `isAvailable` 表示本次权益是否领取成功；失败原因仅用于展示提示。
  bool get isSuccess => isAvailable;
}
