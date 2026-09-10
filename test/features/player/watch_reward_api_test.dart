import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/player/data/watch_reward_repository_provider.dart';
import 'package:drama_client/features/rewards/data/remote/reward_coins_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

class Adapter implements HttpClientAdapter {
  Object? data;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': data, 'message': 'ok'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Adapter adapter;
  late RemoteWatchRewardRepository repository;
  setUp(() {
    adapter = Adapter();
    repository = RemoteWatchRewardRepository(
      RewardCoinsRemoteDataSource(
        apiClient: ApiClient(
          dio: Dio()..httpClientAdapter = adapter,
          requestContext: const ApiRequestContext.test(
            accessToken: 'test-token',
          ),
        ),
      ),
    );
  });
  test(
    'GET requests businessType=2/rewardType=0 and parses int64 strings',
    () async {
      adapter.data = {
        'items': [
          {
            'claimed': false,
            'completed': false,
            'conditionText': 'watch',
            'cycleType': 'TASK_CYCLE_TYPE_DAILY',
            'displayName': 'Watch',
            'progressValue': '123',
            'rewardMax': '20',
            'rewardMin': '10',
            'rewardType': 'REWARD_TYPE_MEMBER_POINT',
            'targetValue': '300',
            'taskKey': 'point.watch.5m',
          },
        ],
      };
      final tasks = await repository.getWatchTasks();
      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.path, '/api/activity/task/list');
      expect(adapter.request!.queryParameters, {
        'businessType': 2,
        'rewardType': 0,
      });
      expect(tasks.single.targetValue, 300);
      expect(tasks.single.progressValue, 123);
      expect(tasks.single.rewardMax, 20);
    },
  );
  test(
    'claim posts taskKey and preserves all complete status enum strings',
    () async {
      for (final status in [
        'CLAIM_STATUS_PENDING',
        'CLAIM_STATUS_PROCESSING',
        'CLAIM_STATUS_SUCCESS',
        'CLAIM_STATUS_RETRY',
        'CLAIM_STATUS_FAILED',
      ]) {
        adapter.data = {
          'balance': '100',
          'claimNo': 'claim-test',
          'grantedAt': '',
          'rewardAmount': '10',
          'rewardType': 'REWARD_TYPE_BONUS_COIN',
          'status': status,
        };
        final result = await repository.claim('coin.watch.5m');
        expect(adapter.request!.method, 'POST');
        expect(adapter.request!.path, '/api/activity/task/reward/claim');
        expect(adapter.request!.data, {'taskKey': 'coin.watch.5m'});
        expect(result.status, status);
        expect(result.rewardAmount, 10);
        expect(result.balance, 100);
        expect(result.isSuccess, status == 'CLAIM_STATUS_SUCCESS');
      }
    },
  );
}
