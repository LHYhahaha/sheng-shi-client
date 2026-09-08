class GiftLinkData {
  const GiftLinkData({
    required this.available,
    required this.benefitDays,
    required this.reGrantAt,
    required this.remainCount,
    required this.shareCode,
    required this.shareUrl,
    required this.totalCount,
    required this.usedCount,
    required this.visible,
    this.cycleStartAt = '',
    this.cycleEndAt = '',
    this.shareUrlExpiresAt = '',
  });

  final bool available;
  final int benefitDays;
  final String reGrantAt;
  final int remainCount;
  final String shareCode;
  final String shareUrl;
  final int totalCount;
  final int usedCount;
  final bool visible;
  final String cycleStartAt;
  final String cycleEndAt;
  final String shareUrlExpiresAt;

  bool get canGift => visible && available && remainCount > 0;
}
