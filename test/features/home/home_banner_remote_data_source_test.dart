import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/home/data/dto/home_banner_response_dto.dart';
import 'package:drama_client/features/home/data/remote/home_banner_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('requests and maps the home-banner configuration', () async {
    final adapter = RecordingHttpAdapter();
    adapter.setResponse(
      'GET',
      '/api/config/home-banner',
      RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'banners': [
            {
              'banner_id': 'home_banner_001',
              'image_url': 'https://example.test/banner.png',
              'jump_type': 'drama',
              'jump_param': '720',
            },
          ],
        }),
      ),
    );
    final source = HomeBannerRemoteDataSource(apiClient: _apiClient(adapter));

    final result = await source.fetchBanners();

    expect(result.banners, hasLength(1));
    expect(result.banners.single.bannerId, 'home_banner_001');
    expect(result.banners.single.jumpType, 'drama');
    expect(result.banners.single.jumpParam, '720');
    expect(adapter.requests.single.path, '/api/config/home-banner');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer token');
  });

  test('normalizes a protocol-less H5 URL to HTTPS', () {
    final banner = HomeBannerDto.fromJson({
      'banner_id': 'home_banner_001',
      'image_url': 'https://example.test/banner.png',
      'jump_type': 'internal_h5',
      'jump_param': 'www.baidu.com',
    });

    expect(banner.normalizedH5Url, 'https://www.baidu.com');
  });
}

ApiClient _apiClient(RecordingHttpAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://banner.example.test'));
  dio.httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: const ApiRequestContext.test(accessToken: 'token'),
  );
}
