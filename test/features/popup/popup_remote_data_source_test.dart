import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/popup/data/remote/popup_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('requests popup by placement code and maps response fields', () async {
    final adapter = RecordingHttpAdapter();
    adapter.setResponse(
      'GET',
      '/api/popup',
      RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'id': 12,
          'name': 'Home Campaign',
          'placement_code': 'home_enter',
          'content_mode': 1,
          'popup_image': 'https://example.test/popup.png',
          'show_close_button': 1,
          'jump_type': 2,
          'h5_url': 'https://example.test/landing',
          'page_code': 'store',
          'short_jump_mode': 0,
          'short_drama_id': 99,
        }),
      ),
    );
    final source = PopupRemoteDataSource(
      apiClient: _apiClientWith(adapter: adapter),
    );

    final dto = await source.fetchPopup(placementCode: 'home_enter');

    expect(dto?.id, 12);
    expect(dto?.placementCode, 'home_enter');
    expect(dto?.popupImage, 'https://example.test/popup.png');
    expect(dto?.jumpType, 2);

    final request = adapter.requests.single;
    expect(request.path, '/api/popup');
    expect(request.queryParameters['placement_code'], 'home_enter');
    expect(request.headers['Authorization'], 'Bearer token');
  });

  test('maps empty popup data to null', () async {
    final adapter = RecordingHttpAdapter();
    adapter.setResponse(
      'GET',
      '/api/popup',
      RecordingHttpResponse(body: apiEnvelopeSuccess(null)),
    );
    final source = PopupRemoteDataSource(
      apiClient: _apiClientWith(adapter: adapter),
    );

    final dto = await source.fetchPopup(placementCode: 'recommend_tab_enter');

    expect(dto, isNull);
  });

  test(
    'requests detail exit recommendations by drama id and maps dramas',
    () async {
      final adapter = RecordingHttpAdapter();
      adapter.setResponse(
        'GET',
        '/api/popup/detail/exit',
        RecordingHttpResponse(
          body: apiEnvelopeSuccess({
            'dramas': [
              {
                'id': 451,
                'sort': 390,
                'cover_url': 'https://example.test/451.jpg',
                'title': 'dragon_returns_in_city_451',
                'summary': 'A dragon returns and dominates the whole city.',
                'tags_name': ['emotional', 'love_at_first_sight'],
                'category_names': ['精选', 'test2'],
                'play_count': 8,
                'trailer_episode_num': 1,
                'is_vip_only': 0,
                'status': 1,
                'episode_total': 4,
              },
            ],
          }),
        ),
      );
      final source = PopupRemoteDataSource(
        apiClient: _apiClientWith(adapter: adapter),
      );

      final dto = await source.fetchDetailExitPopup(dramaId: '720');

      expect(dto.dramas, hasLength(1));
      expect(dto.dramas.single.id, 451);
      expect(dto.dramas.single.title, 'dragon_returns_in_city_451');
      expect(dto.dramas.single.categoryNames, ['精选', 'test2']);

      final request = adapter.requests.single;
      expect(request.path, '/api/popup/detail/exit');
      expect(request.queryParameters['drama_id'], '720');
      expect(request.headers['Authorization'], 'Bearer token');
    },
  );
}

ApiClient _apiClientWith({required RecordingHttpAdapter adapter}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://popup.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: const ApiRequestContext.test(accessToken: 'token'),
  );
}
