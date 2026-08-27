import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/gift/data/remote/gift_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test(
    'loads VIP and drama gift links with their required GET parameters',
    () async {
      final adapter = RecordingHttpAdapter(
        defaultResponse: RecordingHttpResponse(
          body: apiEnvelopeSuccess({
            'available': true,
            'benefitDays': 1,
            'reGrantAt': '2026/08/27',
            'remainCount': 2,
            'shareCode': 'gift123',
            'shareUrl': 'https://example.test/gift123',
            'totalCount': 3,
            'usedCount': 1,
            'visible': true,
          }),
        ),
      );
      final source = GiftRemoteDataSource(apiClient: _apiClient(adapter));

      final vip = await source.getVipGiftLink();
      final drama = await source.getDramaGiftLink(dramaId: 42);

      expect(vip.shareCode, 'gift123');
      expect(drama.benefitDays, 1);
      expect(adapter.requests.map((request) => request.path), [
        '/api/user/gift/vip-link',
        '/api/user/gift/drama-link',
      ]);
      expect(adapter.requests[0].queryParameters, isEmpty);
      expect(adapter.requests[1].queryParameters['dramaId'], 42);
    },
  );
}

ApiClient _apiClient(RecordingHttpAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: const ApiRequestContext(
      deviceId: 'test-install-id',
      lang: 'en',
      platform: 'android',
      appVersion: '1.0.0',
      regionCode: '',
      accessToken: 'test-token',
      refreshToken: null,
      accessTokenExpiresAt: null,
      refreshTokenExpiresAt: null,
      sessionId: null,
      guestId: null,
    ),
  );
}
