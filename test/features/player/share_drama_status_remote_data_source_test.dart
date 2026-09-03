import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('loads the daily drama-share reward status', () async {
    final adapter = RecordingHttpAdapter(
      defaultResponse: RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'claimed': true,
          'completed': true,
          'info': {'configKey': 'coin.share_drama', 'minValue': '12'},
        }),
      ),
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'));
    dio.httpClientAdapter = adapter;
    final source = PlayerRemoteDataSource(
      apiClient: ApiClient(
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
      ),
    );

    final status = await source.fetchShareDramaStatus();

    expect(status.shareCoin, 12);
    expect(status.claimed, isTrue);
    expect(status.completed, isTrue);
    expect(status.taskKey, 'coin.share_drama');
    expect(adapter.requests.single.path, '/api/activity/share-drama/info');
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.queryParameters, isEmpty);
  });
}
