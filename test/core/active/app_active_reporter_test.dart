import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drama_client/core/active/app_active_device_info.dart';
import 'package:drama_client/core/active/app_active_reporter.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/recording_http_adapter.dart';

void main() {
  late RecordingHttpAdapter adapter;
  late DateTime now;
  late AppActiveReporter reporter;

  setUp(() {
    adapter = RecordingHttpAdapter();
    now = DateTime.utc(2026, 7, 6, 10);
    reporter = AppActiveReporter(
      apiClient: _apiClient(adapter),
      deviceInfoReader: _FakeDeviceInfoReader(),
      pushTokenReader: () async => 'fcm-push-token',
      now: () => now,
    );
  });

  test('reports required device fields on app launch', () async {
    await reporter.reportAppLaunch();

    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/user/active/report');
    expect(request.headers['Authorization'], 'Bearer test-token');
    expect(request.data, {
      'channelSource': 'tiktok',
      'region': 'US',
      'timezone': 'America/New_York',
      'pushToken': 'fcm-push-token',
    });
  });

  test('does not send pushToken when FCM token is unavailable', () async {
    reporter = AppActiveReporter(
      apiClient: _apiClient(adapter),
      deviceInfoReader: _FakeDeviceInfoReader(),
      pushTokenReader: () async => null,
      now: () => now,
    );

    await reporter.reportAppLaunch();

    expect(
      (adapter.requests.single.data! as Map).containsKey('pushToken'),
      isFalse,
    );
  });

  test(
    'can send the initial launch report without an available FCM token',
    () async {
      await reporter.reportAppLaunch(includePushToken: false);

      expect(
        (adapter.requests.single.data! as Map).containsKey('pushToken'),
        isFalse,
      );
    },
  );

  test(
    'queues an FCM-ready token report while the initial report is in flight',
    () async {
      final deviceInfo = _DelayedDeviceInfoReader();
      reporter = AppActiveReporter(
        apiClient: _apiClient(adapter),
        deviceInfoReader: deviceInfo,
        pushTokenReader: () async => 'fcm-push-token',
        now: () => now,
      );

      final initialReport = reporter.reportAppLaunch(includePushToken: false);
      await deviceInfo.started.future;
      final tokenReport = reporter.reportAppLaunch();

      deviceInfo.complete();
      await initialReport;
      await tokenReport;

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.first.data, {
        'channelSource': 'tiktok',
        'region': 'US',
        'timezone': 'America/New_York',
      });
      expect(
        (adapter.requests.last.data! as Map)['pushToken'],
        'fcm-push-token',
      );
    },
  );

  test('reports an empty channelSource when channel is unavailable', () async {
    reporter = AppActiveReporter(
      apiClient: _apiClient(adapter),
      deviceInfoReader: _FakeDeviceInfoReader(channelSource: ''),
      now: () => now,
    );

    await reporter.reportAppLaunch();

    expect((adapter.requests.single.data! as Map)['channelSource'], isEmpty);
  });

  test('skips reporting when session initialization failed', () async {
    reporter = AppActiveReporter(
      apiClient: _apiClient(adapter, accessToken: null),
      deviceInfoReader: _FakeDeviceInfoReader(),
      now: () => now,
    );

    await reporter.reportAppLaunch();

    expect(adapter.requests, isEmpty);
  });

  test('does not throw when device info cannot be read', () async {
    reporter = AppActiveReporter(
      apiClient: _apiClient(adapter),
      deviceInfoReader: _FailingDeviceInfoReader(),
      now: () => now,
    );

    await expectLater(reporter.reportAppLaunch(), completes);
    expect(adapter.requests, isEmpty);
  });

  test('does not throw when active report request fails', () async {
    adapter.fetchException = DioException(
      requestOptions: RequestOptions(path: '/api/user/active/report'),
      type: DioExceptionType.connectionError,
    );

    await expectLater(reporter.reportAppLaunch(), completes);
    expect(adapter.requests, hasLength(1));
  });

  test('reports again only after more than 30 minutes in background', () async {
    await reporter.onLifecycleChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 30));
    await reporter.onLifecycleChanged(AppLifecycleState.resumed);
    expect(adapter.requests, isEmpty);

    await reporter.onLifecycleChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 30, seconds: 1));
    await reporter.onLifecycleChanged(AppLifecycleState.resumed);
    expect(adapter.requests, hasLength(1));
  });
}

class _FakeDeviceInfoReader implements AppActiveDeviceInfoReader {
  _FakeDeviceInfoReader({this.channelSource = 'tiktok'});

  final String channelSource;

  @override
  Future<AppActiveDeviceInfo> read() async {
    return AppActiveDeviceInfo(
      channelSource: channelSource,
      region: 'US',
      timezone: 'America/New_York',
    );
  }
}

class _FailingDeviceInfoReader implements AppActiveDeviceInfoReader {
  @override
  Future<AppActiveDeviceInfo> read() async {
    throw StateError('device info unavailable');
  }
}

class _DelayedDeviceInfoReader implements AppActiveDeviceInfoReader {
  final started = Completer<void>();
  final _result = Completer<void>();

  void complete() => _result.complete();

  @override
  Future<AppActiveDeviceInfo> read() async {
    if (!started.isCompleted) {
      started.complete();
    }
    await _result.future;
    return _FakeDeviceInfoReader().read();
  }
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
