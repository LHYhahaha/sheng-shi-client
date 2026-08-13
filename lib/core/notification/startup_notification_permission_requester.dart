import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

/// 应用启动后的唯一通知权限申请入口。
<<<<<<< HEAD
///
/// Android 13 及以上由此发起标准 `POST_NOTIFICATIONS` 授权；低版本没有
/// 对应运行时权限，调用会直接读取系统通知开关，不会重复展示系统授权框。
=======
>>>>>>> 4968f98a5543f924dd83663ae2c58f2e35c7c770
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
<<<<<<< HEAD
      // 通知权限不可用不能影响应用首屏或会话初始化。
=======
>>>>>>> 4968f98a5543f924dd83663ae2c58f2e35c7c770
      debugPrint('[NotificationPermission] Startup request ignored: $error');
    }
  }
}
