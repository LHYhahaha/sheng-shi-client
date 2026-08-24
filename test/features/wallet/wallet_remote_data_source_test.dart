import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/wallet/data/dto/wallet_page_dto.dart';
import 'package:drama_client/features/wallet/data/dto/wallet_reward_coin_record_dto.dart';
import 'package:drama_client/features/wallet/data/dto/wallet_transaction_record_dto.dart';
import 'package:drama_client/features/wallet/data/mapper/wallet_mapper.dart';
import 'package:drama_client/features/wallet/data/remote/wallet_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

void main() {
  test('timezone-less order times are parsed as UTC', () {
    final dto = WalletTransactionRecordDto.fromJson({
      'orderNo': 'order-1',
      'paidAt': '2026-08-03T12:34:56',
    });

    expect(dto.createdAt, DateTime.utc(2026, 8, 3, 12, 34, 56));
    expect(dto.createdAt!.isUtc, isTrue);
  });

  test('history endpoints stay GET and send page query parameters', () async {
    final adapter = RecordingHttpAdapter(
      defaultResponse: RecordingHttpResponse(
        body: apiEnvelopeSuccess({
          'list': [],
          'page': {'page': 2, 'pageSize': 20, 'total': 40},
        }),
      ),
    );
    final dataSource = WalletRemoteDataSource(apiClient: _apiClient(adapter));

    await dataSource.listTransactions(pageToken: '2');
    await dataSource.listSpentConsumptionRecords(pageToken: '2');
    await dataSource.listExpiredConsumptionRecords(pageToken: '2');
    await dataSource.listRewardCoins(pageToken: '2');

    expect(adapter.requests.map((request) => request.method), [
      'GET',
      'GET',
      'GET',
      'GET',
    ]);
    expect(adapter.requests.map((request) => request.path), [
      '/api/payment/recharge/records',
      '/api/payment/consume-records',
      '/api/payment/expired-records',
      '/api/payment/bonus-coin/records',
    ]);
    for (final request in adapter.requests.take(1)) {
      expect(request.queryParameters['page.page'], 2);
      expect(request.queryParameters['page.pageSize'], 20);
    }
    for (final request in adapter.requests.skip(1).take(2)) {
      expect(request.queryParameters['page'], 2);
      expect(request.queryParameters['pageSize'], 20);
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

  test('reward coin records preserve their source metadata', () {
    final dto = WalletRewardCoinRecordDto.fromJson({
      'recordId': '1001',
      'bonusCoin': '50',
      'remainBonusCoin': '20',
      'sourceName': 'Check-in reward',
      'sourceType': 2,
      'sourceOrderNo': 'checkin-20260727',
      'status': 2,
      'startAt': '2026-07-27T00:00:00Z',
      'expireAt': '2026-08-27T00:00:00Z',
      'permanent': false,
    });
    final record = const WalletMapper().mapReward(dto);

    expect(dto.sourceType, 2);
    expect(dto.sourceOrderNo, 'checkin-20260727');
    expect(record.rewardSourceType, 2);
    expect(record.sourceOrderNo, 'checkin-20260727');
    expect(record.subtitle, 'Check-in reward');
  });

  test('permanent reward coin records use the permanent validity text', () {
    final dto = WalletRewardCoinRecordDto.fromJson({
      'recordId': '1002',
      'bonusCoin': '50',
      'remainBonusCoin': '50',
      'sourceName': 'Admin credit',
      'sourceType': 1,
      'sourceOrderNo': 'admin-20260727',
      'status': 1,
      'permanent': true,
    });

    final record = const WalletMapper().mapReward(dto);

    expect(record.validityLabelText?.key, 'reward_coins.validity.permanent');
    expect(record.validityLabelText?.fallbackEn, 'Never Expires');
    expect(record.validityLabelText?.fallbackZh, '永久有效');
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
