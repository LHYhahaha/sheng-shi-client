import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

/// 应用启动后的唯一通知权限申请入口。
class StartupNotificationPermissionRequester {
  Future<void>? _request;

  Future<void> requestIfNeeded() {
    return _request ??= _requestIfNeeded();
  }

  Future<void> _requestIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final current = await permissions.Permission.notification.status;
      if (current.isGranted ||
          current.isProvisional ||
          current.isPermanentlyDenied ||
          current.isRestricted) {
        debugPrint(
          '[NotificationPermission] Startup request skipped: $current',
        );
        return;
      }

      final result = await permissions.Permission.notification.request();
      debugPrint('[NotificationPermission] Startup request result: $result');
    } catch (error) {
      debugPrint('[NotificationPermission] Startup request ignored: $error');
    }
  }
}
