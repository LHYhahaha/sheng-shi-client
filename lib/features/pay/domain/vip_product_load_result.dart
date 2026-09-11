/// One completed catalog attempt; identity distinguishes retries with equal results.
class VipProductLoadResult {
  VipProductLoadResult(this.result);

  factory VipProductLoadResult.loaded({
    required int sourceCount,
    required int displayCount,
  }) => VipProductLoadResult(
    displayCount > 0
        ? 'success'
        : sourceCount == 0
        ? 'empty'
        : 'google_request_failed',
  );

  final String result;
}

/// Google Billing failed to return product data.
class VipProductGoogleRequestException implements Exception {
  VipProductGoogleRequestException(this.cause);
  final Object cause;

  @override
  String toString() => cause.toString();
}
