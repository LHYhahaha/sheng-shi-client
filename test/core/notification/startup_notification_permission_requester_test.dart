import 'package:drama_client/core/notification/startup_notification_permission_requester.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

void main() {
  test('supports notification permission requests on iOS and Android', () {
    expect(supportsNotificationRuntimeRequest(TargetPlatform.iOS), isTrue);
    expect(supportsNotificationRuntimeRequest(TargetPlatform.android), isTrue);
    expect(supportsNotificationRuntimeRequest(TargetPlatform.macOS), isFalse);
  });

  test('requests only once and persists a granted initial result', () async {
    var attempted = false;
    var requestCount = 0;
    StartupNotificationPermissionRequestResult? savedResult;
    final requester = StartupNotificationPermissionRequester(
      supportsRuntimeRequest: () => true,
      getAttempted: () async => attempted,
      markAttempted: () async => attempted = true,
      requestPermission: () async {
        requestCount++;
        return permissions.PermissionStatus.granted;
      },
      saveInitialResult: (result) async => savedResult = result,
    );

    await requester.requestIfNeeded();
    await requester.requestIfNeeded();

    expect(requestCount, 1);
    expect(attempted, isTrue);
    expect(savedResult, StartupNotificationPermissionRequestResult.granted);
  });

  test('persists not determined when the system request throws', () async {
    StartupNotificationPermissionRequestResult? savedResult;
    final requester = StartupNotificationPermissionRequester(
      supportsRuntimeRequest: () => true,
      getAttempted: () async => false,
      markAttempted: () async {},
      requestPermission: () async => throw StateError('platform unavailable'),
      saveInitialResult: (result) async => savedResult = result,
    );

    await requester.requestIfNeeded();

    expect(
      savedResult,
      StartupNotificationPermissionRequestResult.notDetermined,
    );
  });
}
