import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/search/data/remote/search_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('reports a completed search result click by drama id', () async {
    final adapter = RecordingHttpAdapter();
    adapter.setResponse(
      'POST',
      '/api/home/search/stat',
      RecordingHttpResponse(body: apiEnvelopeSuccess(null)),
    );
    final source = SearchRemoteDataSource(
      apiClient: _apiClientWith(adapter: adapter),
    );

    await source.reportSearchResultClick(dramaId: 'drama-42');

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/home/search/stat');
    expect(request.data, {'drama_id': 'drama-42'});
    expect(request.headers['Authorization'], 'Bearer token');
  });
}

ApiClient _apiClientWith({required RecordingHttpAdapter adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://search.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: const ApiRequestContext.test(accessToken: 'token'),
  );
}
