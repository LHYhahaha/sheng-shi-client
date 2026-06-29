import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/wallet/data/dto/wallet_page_dto.dart';
import 'package:drama_client/features/wallet/data/remote/wallet_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('history endpoints stay GET and send page query parameters', () async {
    final adapter = RecordingHttpAdapter(
      defaultResponse: RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'list': [],
          'page': {'page': 2, 'pageSize': 20, 'total': 40},
        }),
      ),
    );
    final dataSource = WalletRemoteDataSource(
      apiClient: _apiClient(adapter),
    );

    await dataSource.listTransactions(pageToken: '2');
    await dataSource.listConsumptionRecords(status: 'spent', pageToken: '2');
    await dataSource.listRewardCoins(pageToken: '2');

    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'GET',
      'GET',
    ]);
    expect(adapter.requests.map((request) => request.path), [
      '/api/payment/recharge/records',
      '/api/payment/coin/consume-records',
      '/api/payment/bonus-coin/records',
    ]);
    for (final request in adapter.requests) {
      expect(request.queryParameters['page.page'], 2);
      expect(request.queryParameters['page.pageSize'], 20);
    }
  });

  test('page dto computes next token from common page shapes', () {
    final backendPage = WalletPageDto<Object?>.fromJson({
      'list': const [1],
      'page': {'page': 1, 'pageSize': 20, 'total': 21},
    }, (json) => json);
    final pageByTotal = WalletPageDto<Object?>.fromJson({
      'records': const [1],
      'page': {'current': '1', 'pageSize': '20', 'total': '21'},
    }, (json) => json);
    final pageByPages = WalletPageDto<Object?>.fromJson({
      'rows': const [1],
      'currentPage': 2,
      'pages': 3,
    }, (json) => json);

    expect(backendPage.items, [1]);
    expect(backendPage.nextPageToken, '2');
    expect(pageByTotal.items, [1]);
    expect(pageByTotal.nextPageToken, '2');
    expect(pageByPages.items, [1]);
    expect(pageByPages.nextPageToken, '3');
  });
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
      accessToken: 'test-token',
    ),
  );
}
