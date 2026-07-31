/// `/api/payment/order/options` 请求参数。
class PaymentOrderOptionsRequestDto {
  const PaymentOrderOptionsRequestDto({
    required this.osType,
    required this.payScene,
    required this.productId,
    required this.productType,
    this.countryCode,
    this.dramaId,
    this.episodeId,
    this.episodeNo,
    this.scene,
  });

  final String? countryCode;
  final int? dramaId;
  final int? episodeId;
  final int? episodeNo;
  final int osType;
  final int payScene;
  final int productId;
  final int productType;
  final String? scene;

  Map<String, Object?> toJson() => <String, Object?>{
    if (countryCode != null) 'countryCode': countryCode,
    if (dramaId != null) 'dramaId': dramaId,
    if (episodeId != null) 'episodeId': episodeId,
    if (episodeNo != null) 'episodeNo': episodeNo,
    'osType': osType,
    'payScene': payScene,
    'productId': productId,
    'productType': productType,
    if (scene != null) 'scene': scene,
  };
}
