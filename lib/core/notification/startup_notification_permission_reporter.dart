import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_client_provider.dart';

/// 首页首次可用时检查通知权限；绝不主动触发系统授权弹窗。
class StartupNotificationPermissionReporter {
  StartupNotificationPermissionReporter({
    required ApiClient apiClient,
    Future<permissions.PermissionStatus> Function()? getStatus,
    Future<bool> Function()? hasCheckedOnHome,
    Future<void> Function()? markCheckedOnHome,
    Future<void> Function()? reportEnablePush,
  }) : _apiClient = apiClient,
       _getStatus = getStatus ?? _defaultGetStatus,
       _hasCheckedOnHome = hasCheckedOnHome ?? _defaultHasCheckedOnHome,
       _markCheckedOnHome = markCheckedOnHome ?? _defaultMarkCheckedOnHome,
       _reportEnablePush =
           reportEnablePush ?? (() => _defaultReportEnablePush(apiClient));

  final ApiClient _apiClient;
  final Future<permissions.PermissionStatus> Function() _getStatus;
  final Future<bool> Function() _hasCheckedOnHome;
  final Future<void> Function() _markCheckedOnHome;
  final Future<void> Function() _reportEnablePush;

  bool _checkInFlight = false;

  Future<void> checkAndReportOnHomeArrival() async {
    if (_checkInFlight) return;

    // 上报接口需要 Authorization；token 未就绪时不检查，以便认证完成后再执行。
    final accessToken = _apiClient.requestContext.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;

    _checkInFlight = true;
    try {
      if (await _hasCheckedOnHome()) return;

      final currentStatus = await _getStatus();
      // 无论是否授权，只在首次到达首页时检查一次，避免后续启动重复判断。
      await _markCheckedOnHome();

      if (_isGranted(currentStatus)) {
        unawaited(_reportEnablePushSafely());
      }
    } catch (error) {
      // 通知权限检查不应影响应用启动。
      debugPrint('[HomeNotificationPermission] Ignored error: $error');
    } finally {
      _checkInFlight = false;
    }
  }

  Future<void> _reportEnablePushSafely() async {
    try {
      await _reportEnablePush();
    } catch (error) {
      // 上报失败不可阻塞权限或启动流程。
      debugPrint('[StartupNotificationPermission] Report ignored: $error');
    }
  }

  static bool _isGranted(permissions.PermissionStatus status) {
    return status.isGranted || status.isProvisional;
  }
}

Future<void> _defaultReportEnablePush(ApiClient apiClient) {
  return apiClient.post<void>(
    '/api/activity/task/action/report',
    authPolicy: ApiAuthPolicy.required,
    data: const <String, String>{'actionKey': 'enable_push'},
    decoder: (_) {},
  );
}

Future<permissions.PermissionStatus> _defaultGetStatus() {
  return permissions.Permission.notification.status;
}

const _checkedOnHomePreferenceKey =
    'notification_permission.checked_on_home.v1';

Future<bool> _defaultHasCheckedOnHome() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(_checkedOnHomePreferenceKey) ?? false;
}

Future<void> _defaultMarkCheckedOnHome() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(_checkedOnHomePreferenceKey, true);
}

final startupNotificationPermissionReporterProvider =
    Provider<StartupNotificationPermissionReporter>((ref) {
      return StartupNotificationPermissionReporter(
        apiClient: ref.watch(apiClientProvider),
      );
    });
