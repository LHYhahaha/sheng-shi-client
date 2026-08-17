import 'package:dio/dio.dart';
import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/core/notification/startup_notification_permission_requester.dart';
import 'package:drama_client/core/notification/startup_notification_permission_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/recording_http_adapter.dart';

void main() {
  late RecordingHttpAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    adapter = RecordingHttpAdapter();
  });

  test('reports denied on the first check for an account', () async {
    bool? reportedEnabled;
    final reporter = StartupNotificationPermissionReporter(
      apiClient: _apiClient(adapter),
      getStatus: () async => permissions.PermissionStatus.denied,
      getLastReportedEnabled: (_) async => null,
      markReportedEnabled: (_, enabled) async => reportedEnabled = enabled,
      reportEnablePush: (enabled) async => reportedEnabled = enabled,
    );

    await reporter.syncForAccount('show-a');

    expect(reportedEnabled, isFalse);
  });

  test(
    'does not report when an account permission status is unchanged',
    () async {
      var checked = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async {
          checked = true;
          return permissions.PermissionStatus.granted;
        },
        getLastReportedEnabled: (_) async => true,
        reportEnablePush: (_) async => fail('must not report'),
      );

      await reporter.syncForAccount('show-a');

      expect(checked, isTrue);
    },
  );

  test(
    'reports a changed status and persists it only after reporting',
    () async {
      var persisted = false;
      var reportFinished = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async => permissions.PermissionStatus.denied,
        getLastReportedEnabled: (_) async => true,
        reportEnablePush: (enabled) async {
          expect(enabled, isFalse);
          reportFinished = true;
        },
        markReportedEnabled: (_, enabled) async {
          expect(reportFinished, isTrue);
          expect(enabled, isFalse);
          persisted = true;
        },
      );

      await reporter.syncForAccount('show-a');

      expect(persisted, isTrue);
    },
  );

  test('uses independent status records for different show IDs', () async {
    final reports = <bool>[];
    final reporter = StartupNotificationPermissionReporter(
      apiClient: _apiClient(adapter),
      getStatus: () async => permissions.PermissionStatus.granted,
      getLastReportedEnabled: (showId) async =>
          showId == 'show-a' ? true : null,
      reportEnablePush: (enabled) async {
        reports.add(enabled);
      },
    );

    await reporter.syncForAccount('show-a');
    await reporter.syncForAccount('show-b');

    expect(reports, [true]);
  });

  test(
    'does not check notification permission without a show ID or token',
    () async {
      var checked = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter, accessToken: null),
        getStatus: () async {
          checked = true;
          return permissions.PermissionStatus.granted;
        },
        getLastReportedEnabled: (_) async => null,
        reportEnablePush: (_) async {},
        markReportedEnabled: (_, _) async {},
      );

      await reporter.syncForAccount(null);
      await reporter.syncForAccount('show-a');

      expect(checked, isFalse);
    },
  );

  test(
    'tracks the first detected status and later notification status changes',
    () async {
      var permission = permissions.PermissionStatus.denied;
      String? storedAnalyticsStatus;
      final sink = AnalyticsInMemoryEventSink(logEvents: false);
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async => permission,
        getLastReportedEnabled: (_) async => false,
        markReportedEnabled: (_, _) async {},
        reportEnablePush: (_) async {},
        analytics: AnalyticsService(
          contextReader: () => const AnalyticsContext(
            platform: 'android',
            appVersion: '1.0.3',
            language: 'en',
            userId: 'show-a',
          ),
          eventSink: sink,
        ),
        getLastAnalyticsStatus: (_) async => storedAnalyticsStatus,
        markAnalyticsStatus: (_, status) async {
          storedAnalyticsStatus = status;
        },
      );

      // 首次普通读取到的状态也要记录，供漏斗分析未授权用户。
      await reporter.syncForAccount('show-a');
      expect(sink.events, hasLength(1));
      expect(sink.events.single.eventParams, {'permission_status': 'denied'});

      // 相同状态的后续启动检查不重复记录。
      await reporter.syncForAccount('show-a');
      expect(sink.events, hasLength(1));

      permission = permissions.PermissionStatus.granted;
      await reporter.syncForAccount('show-a');
      expect(sink.events, hasLength(2));
      expect(sink.events.last.eventParams, {'permission_status': 'granted'});
    },
  );

  test('reports an indeterminate startup result as disabled', () async {
    bool? reportedEnabled;
    String? storedAnalyticsStatus;
    final sink = AnalyticsInMemoryEventSink(logEvents: false);
    final reporter = StartupNotificationPermissionReporter(
      apiClient: _apiClient(adapter),
      getStatus: () async => permissions.PermissionStatus.granted,
      getStartupResult: () async =>
          StartupNotificationPermissionRequestResult.notDetermined,
      getLastReportedEnabled: (_) async => null,
      markReportedEnabled: (_, _) async {},
      reportEnablePush: (enabled) async => reportedEnabled = enabled,
      analytics: AnalyticsService(
        contextReader: () => const AnalyticsContext(
          platform: 'android',
          appVersion: '1.0.3',
          language: 'en',
          userId: 'show-a',
        ),
        eventSink: sink,
      ),
      getLastAnalyticsStatus: (_) async => storedAnalyticsStatus,
      markAnalyticsStatus: (_, status) async => storedAnalyticsStatus = status,
    );

    await reporter.syncForAccount('show-a');

    expect(reportedEnabled, isFalse);
    expect(sink.events.single.eventParams, {
      'permission_status': 'not_determined',
    });
  });

  test(
    'uses the current system state after the startup result was reported',
    () async {
      bool? reportedEnabled;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async => permissions.PermissionStatus.granted,
        getStartupResult: () async =>
            StartupNotificationPermissionRequestResult.notDetermined,
        getLastReportedEnabled: (_) async => false,
        markReportedEnabled: (_, _) async {},
        reportEnablePush: (enabled) async => reportedEnabled = enabled,
      );

      await reporter.syncForAccount('show-a');

      expect(reportedEnabled, isTrue);
    },
  );
}

ApiClient _apiClient(
  RecordingHttpAdapter adapter, {
  String? accessToken = 'test-token',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    dio: dio,
    requestContext: ApiRequestContext(
      deviceId: 'test-install-id',
      lang: 'en',
      platform: 'android',
      appVersion: '1.0.0',
      accessToken: accessToken,
    ),
  );
}
