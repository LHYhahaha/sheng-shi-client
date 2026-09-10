import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/profile/application/login_reward_provider.dart';
import 'package:drama_client/features/rewards/data/dto/reward_task_list_dto.dart';
import 'package:drama_client/features/rewards/data/remote/reward_coins_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_api_envelope.dart';
import '../../helpers/recording_http_adapter.dart';

Map<String, Object?> task({
  bool completed = false,
  bool claimed = false,
  String amount = '310',
  String key = 'coin.bind_account',
}) => {
  'claimed': claimed,
  'completed': completed,
  'conditionText': '',
  'cycleType': 'TASK_CYCLE_TYPE_ONCE',
  'displayName': 'Login with any account',
  'progressValue': '0',
  'rewardMax': amount,
  'rewardMin': amount,
  'rewardType': 'REWARD_TYPE_BONUS_COIN',
  'targetValue': '1',
  'taskKey': key,
};

void main() {
  test(
    'requests login coin tasks and parses configured string amount',
    () async {
      final adapter = RecordingHttpAdapter(
        responses: {
          'GET /api/activity/task/list': RecordingHttpResponse(
            body: apiEnvelopeSuccess({
              'items': [task()],
            }),
          ),
        },
      );
      final source = RewardCoinsRemoteDataSource(
        apiClient: ApiClient(
          dio: Dio()..httpClientAdapter = adapter,
          requestContext: const ApiRequestContext(
            deviceId: 'test',
            lang: 'en',
            platform: 'android',
            appVersion: '1',
            accessToken: 'test-token',
          ),
        ),
      );
      final result = await source.getTasks(rewardType: 1, businessType: 1);
      expect(adapter.requests.single.queryParameters, {
        'rewardType': 1,
        'businessType': 1,
      });
      expect(loginRewardCoinsForTasks(result.toDomain()), 310);
    },
  );

  test('hides absent, zero, completed and claimed login rewards', () {
    expect(loginRewardCoinsForTasks([]), isNull);
    for (final item in [
      task(amount: '0'),
      task(completed: true),
      task(claimed: true),
      task(key: 'coin.watch.5m'),
    ]) {
      expect(
        loginRewardCoinsForTasks([RewardTaskDto.fromJson(item).toDomain()]),
        isNull,
      );
    }
  });
}
