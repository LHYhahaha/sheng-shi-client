import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/gift/data/remote/gift_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('parses gift cycle timestamps without losing nanosecond precision', () {
    final gift = GiftLinkDataDto.fromJson({
      'cycleStartAt': '2026-09-01T00:00:00.123456789Z',
      'cycleEndAt': '2026-09-30T23:59:59.999999999Z',
      'shareUrlExpiresAt': '2026-09-10T00:00:00.123456789Z',
    });

    expect(gift.cycleStartAt, '2026-09-01T00:00:00.123456789Z');
    expect(gift.cycleEndAt, '2026-09-30T23:59:59.999999999Z');
    expect(gift.shareUrlExpiresAt, '2026-09-10T00:00:00.123456789Z');
  });

  test(
    'gift eligibility requires visibility, availability and remaining quota',
    () {
      for (final visible in [false, true]) {
        for (final available in [false, true]) {
          for (final remainCount in [-1, 0, 1]) {
            final gift = GiftLinkDataDto.fromJson({
              'visible': visible,
              'available': available,
              'remainCount': remainCount,
            });
            expect(gift.canGift, visible && available && remainCount > 0);
          }
        }
      }
    },
  );

  test('non-member response can omit share information', () async {
    final adapter = RecordingHttpAdapter(
      defaultResponse: RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'visible': false,
          'available': false,
          'remainCount': 0,
          'totalCount': 0,
          'usedCount': 0,
          'cycleStartAt': '2026-09-01T00:00:00Z',
          'cycleEndAt': '2026-09-30T23:59:59Z',
          'reGrantAt': '2026/10/01',
        }),
      ),
    );
    final gift = await GiftRemoteDataSource(
      apiClient: _apiClient(adapter),
    ).getVipGiftLink();

    expect(gift.canGift, isFalse);
    expect(gift.shareCode, isEmpty);
    expect(gift.shareUrl, isEmpty);
    expect(gift.shareUrlExpiresAt, isEmpty);
    expect(gift.reGrantAt, '2026/10/01');
  });

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

  test(
    'claims a gift with the share code and parses its granted benefit',
    () async {
      final adapter = RecordingHttpAdapter(
        defaultResponse: RecordingHttpResponse(
          body: apiEnvelopeSuccess({
            'benefitDays': 3,
            'dramaId': '1506',
            'giftType': 1,
            'isAvailable': true,
            'reason': '',
            // 成功判断仅取 isAvailable，reasonCode 不参与成功分支。
            'reasonCode': 10,
            'shareCode': 'abc1234',
          }),
        ),
      );
      final source = GiftRemoteDataSource(apiClient: _apiClient(adapter));

      final result = await source.claimGift(shareCode: 'abc1234');

      expect(result.benefitDays, 3);
      expect(result.dramaId, '1506');
      expect(result.isDrama, isTrue);
      expect(result.isSuccess, isTrue);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/api/user/gifts/claim');
      expect(adapter.requests.single.data, {'shareCode': 'abc1234'});
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
