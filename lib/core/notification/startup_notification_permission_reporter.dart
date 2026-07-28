import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_client_provider.dart';

/// 将系统通知权限同步给当前账号；不主动触发系统授权弹窗。
///
/// 状态只按服务端提供的 showId 隔离。首次同步也会上报，之后仅在状态变更时上报。
class StartupNotificationPermissionReporter {
  StartupNotificationPermissionReporter({
    required ApiClient apiClient,
    Future<permissions.PermissionStatus> Function()? getStatus,
    Future<bool?> Function(String showId)? getLastReportedEnabled,
    Future<void> Function(String showId, bool enabled)? markReportedEnabled,
    Future<void> Function(bool enabled)? reportEnablePush,
  }) : _apiClient = apiClient,
       _getStatus = getStatus ?? _defaultGetStatus,
       _getLastReportedEnabled =
           getLastReportedEnabled ?? _defaultGetLastReportedEnabled,
       _markReportedEnabled =
           markReportedEnabled ?? _defaultMarkReportedEnabled,
       _reportEnablePush =
           reportEnablePush ??
           ((enabled) => _defaultReportEnablePush(apiClient, enabled));

  final ApiClient _apiClient;
  final Future<permissions.PermissionStatus> Function() _getStatus;
  final Future<bool?> Function(String showId) _getLastReportedEnabled;
  final Future<void> Function(String showId, bool enabled) _markReportedEnabled;
  final Future<void> Function(bool enabled) _reportEnablePush;

  final Map<String, Future<void>> _accountSyncs = <String, Future<void>>{};

  /// 兼容首页旧调用点。通知状态现由登录完成和会员支付成功时同步。
  @Deprecated('Use syncForAccount after authentication or membership purchase.')
  Future<void> checkAndReportOnHomeArrival() async {}

  Future<void> syncForAccount(String? showId) async {
    if (showId == null || showId.isEmpty) {
      return;
    }

    final inFlight = _accountSyncs[showId];
    if (inFlight != null) return inFlight;

    final sync = _syncForAccount(showId);
    _accountSyncs[showId] = sync;
    try {
      await sync;
    } finally {
      if (identical(_accountSyncs[showId], sync)) {
        _accountSyncs.remove(showId);
      }
    }
  }

  Future<void> _syncForAccount(String showId) async {
    final accessToken = _apiClient.requestContext.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      final enabled = _isGranted(await _getStatus());
      final previous = await _getLastReportedEnabled(showId);
      if (previous == enabled) return;

      await _reportEnablePush(enabled);
      // 只有服务端成功接收后才更新本地状态，失败时下一次触发会重试。
      await _markReportedEnabled(showId, enabled);
    } catch (error) {
      debugPrint('[NotificationPermission] Sync ignored: $error');
    }
  }

  static bool _isGranted(permissions.PermissionStatus status) {
    return status.isGranted || status.isProvisional;
  }
}

Future<void> _defaultReportEnablePush(ApiClient apiClient, bool enabled) {
  return apiClient.post<void>(
    '/api/activity/task/action/report',
    authPolicy: ApiAuthPolicy.required,
    data: <String, dynamic>{'actionKey': 'enable_push', 'enabled': enabled},
    decoder: (_) {},
  );
}

Future<permissions.PermissionStatus> _defaultGetStatus() {
  return permissions.Permission.notification.status;
}

String _preferenceKey(String showId) =>
    'notification_permission.reported_enabled.$showId.v2';

Future<bool?> _defaultGetLastReportedEnabled(String showId) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(_preferenceKey(showId));
}

Future<void> _defaultMarkReportedEnabled(String showId, bool enabled) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(_preferenceKey(showId), enabled);
}

final startupNotificationPermissionReporterProvider =
    Provider<StartupNotificationPermissionReporter>((ref) {
      return StartupNotificationPermissionReporter(
        apiClient: ref.watch(apiClientProvider),
      );
    });
