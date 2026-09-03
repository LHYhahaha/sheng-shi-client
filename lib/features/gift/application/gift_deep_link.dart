enum GiftDeepLinkType { drama, temporaryVip }

/// H5 赠送落地页唤起 App 时携带的领取信息。
class GiftDeepLink {
  const GiftDeepLink({
    required this.type,
    required this.shareCode,
    this.dramaId,
  });

  final GiftDeepLinkType type;
  final String shareCode;
  final String? dramaId;

  bool get isTemporaryVip => type == GiftDeepLinkType.temporaryVip;

  static GiftDeepLink? tryParse(Uri uri) {
    final landingType = uri.queryParameters['landing_type']?.trim();
    final shareCode = uri.queryParameters['shareCode']?.trim();
    if (landingType == null ||
        landingType.isEmpty ||
        shareCode == null ||
        shareCode.isEmpty) {
      return null;
    }
    return switch (landingType) {
      'drama_gift' => _dramaGift(uri, shareCode),
      'temp_vip_gift' => GiftDeepLink(
        type: GiftDeepLinkType.temporaryVip,
        shareCode: shareCode,
      ),
      _ => null,
    };
  }

  static GiftDeepLink? _dramaGift(Uri uri, String shareCode) {
    final dramaId = uri.queryParameters['drama_id']?.trim();
    if (dramaId == null || dramaId.isEmpty) return null;
    return GiftDeepLink(
      type: GiftDeepLinkType.drama,
      shareCode: shareCode,
      dramaId: dramaId,
    );
  }
}
