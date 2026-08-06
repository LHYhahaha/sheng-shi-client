import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_definition.dart';
import '../analytics/analytics_event.dart';
import '../analytics/analytics_service.dart';
import '../network/api_client.dart';
import '../network/api_client_provider.dart';
import '../analytics/analytics_provider.dart';

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
    AnalyticsService? analytics,
    Future<String?> Function(String showId)? getLastAnalyticsStatus,
    Future<void> Function(String showId, String status)? markAnalyticsStatus,
  }) : _apiClient = apiClient,
       _getStatus = getStatus ?? _defaultGetStatus,
       _getLastReportedEnabled =
           getLastReportedEnabled ?? _defaultGetLastReportedEnabled,
       _markReportedEnabled =
           markReportedEnabled ?? _defaultMarkReportedEnabled,
       _reportEnablePush =
           reportEnablePush ??
           ((enabled) => _defaultReportEnablePush(apiClient, enabled)),
       _analytics = analytics,
       _getLastAnalyticsStatus =
           getLastAnalyticsStatus ?? _defaultGetLastAnalyticsStatus,
       _markAnalyticsStatus =
           markAnalyticsStatus ?? _defaultMarkAnalyticsStatus;

  final ApiClient _apiClient;
  final Future<permissions.PermissionStatus> Function() _getStatus;
  final Future<bool?> Function(String showId) _getLastReportedEnabled;
  final Future<void> Function(String showId, bool enabled) _markReportedEnabled;
  final Future<void> Function(bool enabled) _reportEnablePush;
  final AnalyticsService? _analytics;
  final Future<String?> Function(String showId) _getLastAnalyticsStatus;
  final Future<void> Function(String showId, String status)
  _markAnalyticsStatus;

  final Map<String, Future<void>> _accountSyncs = <String, Future<void>>{};
  final Set<String> _pendingAnalyticsStatusKeys = <String>{};

  /// 兼容首页旧调用点。通知状态现由登录完成和会员支付成功时同步。
  @Deprecated('Use syncForAccount after authentication or membership purchase.')
  Future<void> checkAndReportOnHomeArrival() async {}

  Future<void> syncForAccount(
    String? showId, {
    bool isExplicitResult = false,
  }) async {
    if (showId == null || showId.isEmpty) {
      return;
    }

    // 明确授权结果不能被同时进行的普通检查合并，否则首次拒绝可能会被忽略。
    final syncKey = '$showId:$isExplicitResult';
    final inFlight = _accountSyncs[syncKey];
    if (inFlight != null) return inFlight;

    final sync = _syncForAccount(showId, isExplicitResult: isExplicitResult);
    _accountSyncs[syncKey] = sync;
    try {
      await sync;
    } finally {
      if (identical(_accountSyncs[syncKey], sync)) {
        _accountSyncs.remove(syncKey);
      }
    }
  }

  /// 用户操作系统授权弹窗后调用。
  ///
  /// 普通 [syncForAccount] 无法区分首次的 `denied` 是尚未弹窗还是用户拒绝；
  /// 此方法将本次读取明确标记为授权结果，使首次拒绝也能进入埋点。
  Future<void> recordExplicitResultForAccount(String? showId) {
    return syncForAccount(showId, isExplicitResult: true);
  }

  Future<void> _syncForAccount(
    String showId, {
    required bool isExplicitResult,
  }) async {
    final accessToken = _apiClient.requestContext.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;

    try {
      final permission = await _getStatus();
      final enabled = _isGranted(permission);
      final previous = await _getLastReportedEnabled(showId);
      if (previous != enabled) {
        await _reportEnablePush(enabled);
        // 只有服务端成功接收后才更新本地状态，失败时下一次触发会重试。
        await _markReportedEnabled(showId, enabled);
      }

      await _trackPermissionStatus(
        showId,
        permission,
        isExplicitResult: isExplicitResult,
      );
    } catch (error) {
      debugPrint('[NotificationPermission] Sync ignored: $error');
    }
  }

  static bool _isGranted(permissions.PermissionStatus status) {
    return status.isGranted || status.isProvisional;
  }

  Future<void> _trackPermissionStatus(
    String showId,
    permissions.PermissionStatus permission, {
    required bool isExplicitResult,
  }) async {
    final analytics = _analytics;
    if (analytics == null) return;

    final status = _analyticsStatus(permission);
    if (status == null) return;

    final pendingKey = '$showId:$status';
    if (!_pendingAnalyticsStatusKeys.add(pendingKey)) return;

    try {
      final previous = await _getLastAnalyticsStatus(showId);
      final isFirstAmbiguousDenial =
          previous == null &&
          status == 'denied' &&
          !isExplicitResult &&
          !permission.isPermanentlyDenied &&
          !permission.isRestricted;
      if (previous == status || isFirstAmbiguousDenial) return;

      final payload = await analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.pushPermissionResult, {
          'permission_status': status,
        }),
      );
      if (payload != null) {
        await _markAnalyticsStatus(showId, status);
      }
    } finally {
      _pendingAnalyticsStatusKeys.remove(pendingKey);
    }
  }

  static String? _analyticsStatus(permissions.PermissionStatus status) {
    if (status.isGranted || status.isProvisional) return 'granted';
    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      return 'denied';
    }
    return null;
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

String _analyticsPreferenceKey(String showId) =>
    'analytics.push_permission_result.status.$showId.v1';

Future<bool?> _defaultGetLastReportedEnabled(String showId) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(_preferenceKey(showId));
}

Future<void> _defaultMarkReportedEnabled(String showId, bool enabled) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(_preferenceKey(showId), enabled);
}

Future<String?> _defaultGetLastAnalyticsStatus(String showId) async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getString(_analyticsPreferenceKey(showId));
}

Future<void> _defaultMarkAnalyticsStatus(String showId, String status) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_analyticsPreferenceKey(showId), status);
}

final startupNotificationPermissionReporterProvider =
    Provider<StartupNotificationPermissionReporter>((ref) {
      return StartupNotificationPermissionReporter(
        apiClient: ref.watch(apiClientProvider),
        analytics: ref.watch(analyticsServiceProvider),
      );
    });
