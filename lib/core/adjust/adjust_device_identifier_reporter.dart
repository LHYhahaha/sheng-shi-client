import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// 将 Adjust 返回的设备广告标识关联到当前内部 Device-Id（由公共请求头携带）。
///
/// 此接口是匿名接口，不能等待登录态，也不携带 Authorization。
class AdjustDeviceIdentifierReporter {
  AdjustDeviceIdentifierReporter({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> report({required String adjustAdid, String? gpsAdid}) async {
    final normalizedAdjustAdid = adjustAdid.trim();
    if (normalizedAdjustAdid.isEmpty) {
      debugPrint(
        '[Adjust] Device identifier report skipped: ADID unavailable.',
      );
      return;
    }

    final normalizedGpsAdid = gpsAdid?.trim();
    try {
      await _apiClient.post<void>(
        '/api/user/device/adjust',
        data: <String, String>{
          'adjustAdid': normalizedAdjustAdid,
          if (normalizedGpsAdid != null && normalizedGpsAdid.isNotEmpty)
            'gpsAdid': normalizedGpsAdid,
        },
        decoder: (_) {},
      );
      debugPrint('[Adjust] Device identifiers reported.');
    } catch (error, stackTrace) {
      // 广告归因不能影响启动、登录或后续业务流程。
      debugPrint('[Adjust] Device identifier report failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
