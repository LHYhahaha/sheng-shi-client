import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/profile/data/remote/global_language_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('fetches global language options from API response map', () async {
    final adapter = RecordingHttpAdapter(
      responses: {
        'GET /api/home/language/global': RecordingHttpResponse(
          body: apiEnvelopeSuccess({'English': 'en', '中文': 'zh'}),
        ),
      },
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final dataSource = GlobalLanguageRemoteDataSource(
      apiClient: ApiClient(
        dio: dio,
        requestContext: const ApiRequestContext(
          deviceId: 'device-1',
          lang: 'en',
          platform: 'ios',
          appVersion: '1.0.0',
          accessToken: 'token-1',
        ),
      ),
    );

    final options = await dataSource.fetchGlobalLanguages();

    expect(adapter.requests.single.path, '/api/home/language/global');
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(options.map((option) => option.label), ['English', '中文']);
    expect(options.map((option) => option.code), ['en', 'zh']);
  });
}
