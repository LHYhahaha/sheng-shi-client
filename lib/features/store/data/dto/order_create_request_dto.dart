class OrderCreateRequestDto {
  const OrderCreateRequestDto({
    required this.productId,
    required this.kind,
    required this.platform,
    this.idempotencyKey,
  });

  final String productId;
  final String kind;
  final String platform;
  final String? idempotencyKey;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'productId': productId,
      'kind': kind,
      'platform': platform,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }
}
