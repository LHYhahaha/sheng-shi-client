import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_definition.dart';
import 'package:drama_client/core/analytics/analytics_event.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/recording_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingHttpAdapter adapter;
  late ApiClient client;
  String? userId;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    userId = null;
    adapter = RecordingHttpAdapter(
      defaultResponse: const RecordingHttpResponse(
        body: {'code': 0, 'data': {}, 'message': 'Success'},
      ),
    );
    final dio = Dio()..httpClientAdapter = adapter;
    client = ApiClient(dio: dio);
    addTearDown(dio.close);
  });
  AnalyticsBatchUploadEventSink sink({bool enabled = true}) {
    final value = AnalyticsBatchUploadEventSink(
      apiClientReader: () => client,
      userIdReader: () => userId,
      uploadsEnabled: enabled,
    );
    addTearDown(value.dispose);
    return value;
  }

  AnalyticsService service(
    AnalyticsBatchUploadEventSink sink, {
    String? snapshotUserId,
  }) => AnalyticsService(
    contextReader: () => AnalyticsContext(
      platform: 'android',
      appVersion: '1',
      language: 'en',
      userId: snapshotUserId,
      pageName: 'original_page',
    ),
    eventSink: sink,
    clock: () => DateTime.fromMillisecondsSinceEpoch(123456),
  );
  const event = AnalyticsEvent(AnalyticsDefinitions.appLaunch, {
    'launch_type': 'cold',
  });
  Map common(int request, [int index = 0]) =>
      (jsonDecode(adapter.requests[request].data! as String)['events']
              as List)[index]['commonParams']
          as Map;

  test(
    'records and persists without ID; later fills only ID and preserves event time',
    () async {
      final queue = sink();
      final recorded = await service(queue).track(event);
      await queue.flush();
      expect(adapter.requests, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('analytics.pending_events.v1'), hasLength(1));
      userId = '2072231756014030848';
      await queue.flush();
      expect(adapter.requests, hasLength(1));
      expect(common(0)['userId'], userId);
      expect(common(0)['eventTime'], 123456);
      expect(common(0)['eventId'], recorded!.commonParams.eventId);
      expect(common(0)['pageName'], 'original_page');
      expect(prefs.getStringList('analytics.pending_events.v1'), isNull);
    },
  );

  test('restores missing ID across restart and never sends blank ID', () async {
    final first = sink();
    final recorded = await service(first).track(event);
    first.dispose();
    final restored = sink();
    userId = '   ';
    await restored.enableUploads();
    expect(adapter.requests, isEmpty);
    userId = 'restored-user';
    await restored.flush();
    expect(common(0)['eventId'], recorded!.commonParams.eventId);
    expect(common(0)['eventTime'], 123456);
    expect(common(0)['userId'], 'restored-user');
  });

  test(
    'known ID uploads while unresolved events remain; old identities are not overwritten',
    () async {
      final queue = sink();
      await service(queue).track(event);
      await service(queue, snapshotUserId: 'original-user').track(event);
      await queue.flush();
      expect(common(0)['userId'], 'original-user');
      userId = 'new-user';
      await queue.flush();
      expect(adapter.requests, hasLength(2));
      expect(common(1)['userId'], 'new-user');
    },
  );

  test(
    'fills while uploads are disabled and preserves ID through upload retry',
    () async {
      final queue = sink(enabled: false);
      await service(queue).track(event);
      userId = 'first-user';
      await queue.flush();
      expect(adapter.requests, isEmpty);
      userId = 'second-user';
      adapter.fetchException = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      await queue.enableUploads();
      final first = common(0);
      adapter.fetchException = null;
      await queue.flush();
      expect(common(1), first);
      expect(common(1)['userId'], 'first-user');
      expect(common(1)['eventTime'], 123456);
    },
  );
}
