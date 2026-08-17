import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:shared_preferences/shared_preferences.dart';

enum StartupNotificationPermissionRequestResult {
  granted,
  denied,
  notDetermined,
}

/// 应用启动后的唯一通知权限申请入口。
///
/// Android 13 及以上由此发起标准 `POST_NOTIFICATIONS` 授权；低版本没有
/// 对应运行时权限，调用会直接读取系统通知开关，不会重复展示系统授权框。
class StartupNotificationPermissionRequester {
  StartupNotificationPermissionRequester({
    bool Function()? supportsRuntimeRequest,
    Future<bool> Function()? getAttempted,
    Future<void> Function()? markAttempted,
    Future<permissions.PermissionStatus> Function()? requestPermission,
    Future<void> Function(StartupNotificationPermissionRequestResult result)?
    saveInitialResult,
  }) : _supportsRuntimeRequest =
           supportsRuntimeRequest ?? _defaultSupportsRuntimeRequest,
       _getAttempted = getAttempted ?? _defaultGetAttempted,
       _markAttempted = markAttempted ?? _defaultMarkAttempted,
       _requestPermission = requestPermission ?? _defaultRequestPermission,
       _saveInitialResult = saveInitialResult ?? _defaultSaveInitialResult;

  Future<void>? _request;
  final bool Function() _supportsRuntimeRequest;
  final Future<bool> Function() _getAttempted;
  final Future<void> Function() _markAttempted;
  final Future<permissions.PermissionStatus> Function() _requestPermission;
  final Future<void> Function(StartupNotificationPermissionRequestResult result)
  _saveInitialResult;

  Future<void> requestIfNeeded() {
    return _request ??= _requestIfNeeded();
  }

  Future<void> _requestIfNeeded() async {
    if (!_supportsRuntimeRequest() || await _getAttempted()) return;

    try {
      await _markAttempted();
      final result = await _requestPermission();
      await _saveInitialResult(_mapResult(result));
      debugPrint('[NotificationPermission] Startup request result: $result');
    } catch (error) {
      await _saveInitialResult(
        StartupNotificationPermissionRequestResult.notDetermined,
      );
      // 通知权限不可用不能影响应用首屏或会话初始化。
      debugPrint('[NotificationPermission] Startup request ignored: $error');
    }
  }

  static StartupNotificationPermissionRequestResult _mapResult(
    permissions.PermissionStatus result,
  ) {
    if (result.isGranted || result.isProvisional) {
      return StartupNotificationPermissionRequestResult.granted;
    }
    if (result.isDenied || result.isPermanentlyDenied || result.isRestricted) {
      return StartupNotificationPermissionRequestResult.denied;
    }
    return StartupNotificationPermissionRequestResult.notDetermined;
  }
}

const _attemptedPreferenceKey =
    'notification_permission.startup_request_attempted.v1';
const _initialResultPreferenceKey =
    'notification_permission.startup_request_result.v1';

bool _defaultSupportsRuntimeRequest() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<bool> _defaultGetAttempted() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(_attemptedPreferenceKey) ?? false;
}

Future<void> _defaultMarkAttempted() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool(_attemptedPreferenceKey, true);
}

Future<permissions.PermissionStatus> _defaultRequestPermission() {
  return permissions.Permission.notification.request();
}

Future<void> _defaultSaveInitialResult(
  StartupNotificationPermissionRequestResult result,
) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_initialResultPreferenceKey, result.name);
}

Future<StartupNotificationPermissionRequestResult?>
getStartupNotificationPermissionRequestResult() async {
  final preferences = await SharedPreferences.getInstance();
  final value = preferences.getString(_initialResultPreferenceKey);
  for (final result in StartupNotificationPermissionRequestResult.values) {
    if (result.name == value) return result;
  }
  return null;
}
