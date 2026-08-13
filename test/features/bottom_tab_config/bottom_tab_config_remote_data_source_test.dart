import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/bottom_tab_config/data/remote/bottom_tab_config_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('requests and maps dynamic bottom-tab configuration', () async {
    final adapter = RecordingHttpAdapter();
    adapter.setResponse(
      'GET',
      '/api/config/bottom-tabs',
      RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'tabs': [
            {
              'h5_url': 'https://example.test/game',
              'name_i18n_key': 'nav_game',
              'normal_icon_url': 'https://example.test/game-normal.png',
              'replace_tab': 'favorites',
              'selected_icon_url': 'https://example.test/game-selected.png',
              'tab_config_id': 'config-42',
            },
          ],
        }),
      ),
    );
    final source = BottomTabConfigRemoteDataSource(
      apiClient: _apiClientWith(adapter),
    );

    final response = await source.fetchBottomTabs();

    expect(response.tabs, hasLength(1));
    final tab = response.tabs.single;
    expect(tab.h5Url, 'https://example.test/game');
    expect(tab.nameI18nKey, 'nav_game');
    expect(tab.normalIconUrl, 'https://example.test/game-normal.png');
    expect(tab.replaceTab, 'favorites');
    expect(tab.selectedIconUrl, 'https://example.test/game-selected.png');
    expect(tab.tabConfigId, 'config-42');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/api/config/bottom-tabs');
    expect(request.headers['Authorization'], 'Bearer token');
  });
}

ApiClient _apiClientWith(RecordingHttpAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://config.example.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: const ApiRequestContext.test(accessToken: 'token'),
  );
}
