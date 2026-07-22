import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/core/notification/startup_notification_permission_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../../helpers/recording_http_adapter.dart';

void main() {
  late RecordingHttpAdapter adapter;

  setUp(() {
    adapter = RecordingHttpAdapter();
  });

  test(
    'does not report enable_push when notification permission is denied',
    () async {
      var reported = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async => permissions.PermissionStatus.denied,
        hasCheckedOnHome: () async => false,
        markCheckedOnHome: () async {},
        reportEnablePush: () async {
          reported = true;
        },
      );

      await reporter.checkAndReportOnHomeArrival();

      expect(reported, isFalse);
    },
  );

  test(
    'reports and marks the check when notification permission is granted',
    () async {
      var marked = false;
      var reported = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async => permissions.PermissionStatus.granted,
        hasCheckedOnHome: () async => false,
        markCheckedOnHome: () async => marked = true,
        reportEnablePush: () async => reported = true,
      );

      await reporter.checkAndReportOnHomeArrival();

      expect(marked, isTrue);
      expect(reported, isTrue);
    },
  );

  test(
    'marks the check but does not report when notification is denied',
    () async {
      var marked = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async => permissions.PermissionStatus.denied,
        hasCheckedOnHome: () async => false,
        markCheckedOnHome: () async => marked = true,
      );

      await reporter.checkAndReportOnHomeArrival();
      expect(marked, isTrue);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'does not check notification permission until an access token is available',
    () async {
      var checked = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter, accessToken: null),
        getStatus: () async {
          checked = true;
          return permissions.PermissionStatus.granted;
        },
      );

      await reporter.checkAndReportOnHomeArrival();
      expect(checked, isFalse);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'does not check or report when home permission status was already recorded',
    () async {
      var checked = false;
      final reporter = StartupNotificationPermissionReporter(
        apiClient: _apiClient(adapter),
        getStatus: () async {
          checked = true;
          return permissions.PermissionStatus.granted;
        },
        hasCheckedOnHome: () async => true,
      );

      await reporter.checkAndReportOnHomeArrival();
      expect(checked, isFalse);
      expect(adapter.requests, isEmpty);
    },
  );

  test('finishes permission flow before a pending report completes', () async {
    final reportCompletion = Completer<void>();
    final reporter = StartupNotificationPermissionReporter(
      apiClient: _apiClient(adapter),
      getStatus: () async => permissions.PermissionStatus.granted,
      hasCheckedOnHome: () async => false,
      markCheckedOnHome: () async {},
      reportEnablePush: () => reportCompletion.future,
    );

    await reporter.checkAndReportOnHomeArrival();

    expect(reportCompletion.isCompleted, isFalse);
    reportCompletion.complete();
  });
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
