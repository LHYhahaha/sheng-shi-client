import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_environment.dart';
import 'fcm_notification.dart';

const _androidNotificationChannel = AndroidNotificationChannel(
  'default_notification_channel',
  'Default notifications',
  description: 'Notifications sent by NovaShort.',
  importance: Importance.high,
);

/// FCM 后台消息入口。必须是顶层函数，且在 [main] 中注册。
@pragma('vm:entry-point')
Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final notification = FcmNotification.fromRemoteMessage(message);
    if (AppConfig.current.isProduction) {
      return;
    }
    _logRemoteMessage('Background message received', message);
    debugPrint(
      '[FCM] Background display model: ${jsonEncode(notification.toPayload())}',
    );
  } catch (error, stackTrace) {
    if (AppConfig.current.isProduction) {
      return;
    }
    debugPrint('[FCM] Background initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

void _logRemoteMessage(String event, RemoteMessage message) {
  if (AppConfig.current.isProduction) {
    return;
  }
  try {
    debugPrint(
      '[FCM] $event full payload: ${jsonEncode(message.toMap())}',
      wrapWidth: 1024,
    );
  } catch (error) {
    debugPrint('[FCM] Failed to serialize $event payload: $error');
  }
}

/// 初始化 FCM、提供 Token，并将前台 FCM 消息展示为本地通知。
///
/// 不申请通知权限；项目已有的用户触发授权流程会负责申请权限。
class FcmNotificationService {
  FcmNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  Future<void>? _initialization;
  final _notificationTapController =
      StreamController<FcmNotification>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();
  FcmNotification? _initialNotificationTap;

  /// 应用已启动时，用户点击系统或本地通知的事件流。
  Stream<FcmNotification> get onNotificationTap =>
      _notificationTapController.stream;

  /// 每次启动和 token 更新时通知上层补发后端绑定。
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  /// 消费由通知冷启动应用时的首个通知事件。
  FcmNotification? takeInitialNotificationTap() {
    final notification = _initialNotificationTap;
    _initialNotificationTap = null;
    return notification;
  }

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    // 通知展示能力异常不能阻断 Token 获取和后端同步。
    await _runNonFatal(
      'local notification initialization',
      _initializeLocalNotifications,
    );
    await _runNonFatal(
      'local notification launch handling',
      _handleLocalNotificationLaunch,
    );
    await _printCurrentToken();
    _listenForTokenRefresh();
    _listenForMessages();
    await _runNonFatal('initial message handling', _handleInitialMessage);
  }

  Future<void> _runNonFatal(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('[FCM] $operation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );
    final androidNotifications = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidNotifications?.createNotificationChannel(
      _androidNotificationChannel,
    );
    await _logAndroidNotificationState(androidNotifications);
  }

  Future<void> _logAndroidNotificationState(
    AndroidFlutterLocalNotificationsPlugin? androidNotifications,
  ) async {
    if (androidNotifications == null) return;
    try {
      final enabled = await androidNotifications.areNotificationsEnabled();
      final channels = await androidNotifications.getNotificationChannels();
      final channel = channels
          ?.where((item) => item.id == _androidNotificationChannel.id)
          .firstOrNull;
      debugPrint(
        '[FCM] Android notification state: enabled=$enabled, '
        'channel=${channel?.id}, importance=${channel?.importance.name}',
      );
    } catch (error) {
      debugPrint('[FCM] Unable to inspect Android notification state: $error');
    }
  }

  Future<void> _printCurrentToken() async {
    try {
      final token = await getPushToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] Token is unavailable. It may be pending APNs setup.');
        return;
      }
      debugPrint('[FCM] Token: $token');
    } catch (error, stackTrace) {
      debugPrint('[FCM] Failed to get token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 获取当前设备的 FCM token，供用户活跃上报等业务接口使用。
  ///
  /// iOS 在 APNs 初始化完成前可能暂时没有 token，因此调用方应能处理 `null`。
  Future<String?> getPushToken() => _messaging.getToken();

  void _listenForTokenRefresh() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      (token) {
        debugPrint('[FCM] Token refreshed: $token');
        if (token.isNotEmpty) _tokenRefreshController.add(token);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[FCM] Token refresh failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void _listenForMessages() {
    _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[FCM] Foreground message failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
    _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpened,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[FCM] Message-open event failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final FcmNotification notification = FcmNotification.fromRemoteMessage(
      message,
    );
    _logRemoteMessage('Foreground message received', message);
    debugPrint(
      '[FCM] Foreground display model: ${jsonEncode(notification.toPayload())}',
    );
    if (!notification.hasDisplayContent) return;

    final image = await _downloadImage(notification.imageUrl, notification.id);
    await _localNotifications.show(
      id: _notificationId(notification.id),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'default_notification_channel',
          'Default notifications',
          channelDescription: 'Notifications sent by NovaShort.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          largeIcon: image,
          styleInformation: image == null
              ? null
              : BigPictureStyleInformation(
                  image,
                  largeIcon: image,
                  hideExpandedLargeIcon: true,
                  showBigPictureWhenCollapsed: true,
                ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(notification.toPayload()),
    );
  }

  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) _handleMessageOpened(message);
  }

  void _handleMessageOpened(RemoteMessage message) {
    final notification = FcmNotification.fromRemoteMessage(message);
    _logRemoteMessage('Remote notification opened', message);
    debugPrint(
      '[FCM] Remote opened display model: ${jsonEncode(notification.toPayload())}',
    );
    _publishNotificationTap(notification);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification opened: payload=${response.payload}');
    final notification = _notificationFromPayload(response.payload);
    if (notification != null) _publishNotificationTap(notification);
  }

  Future<void> _handleLocalNotificationLaunch() async {
    final details = await _localNotifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final notification = _notificationFromPayload(
      details?.notificationResponse?.payload,
    );
    if (notification != null) _publishNotificationTap(notification);
  }

  FcmNotification? _notificationFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      return FcmNotification.fromPayload(decoded);
    } catch (error) {
      debugPrint('[FCM] Invalid local notification payload: $error');
      return null;
    }
  }

  void _publishNotificationTap(FcmNotification notification) {
    if (!_notificationTapController.hasListener) {
      _initialNotificationTap = notification;
      return;
    }
    _notificationTapController.add(notification);
  }

  Future<FilePathAndroidBitmap?> _downloadImage(
    String? imageUrl,
    String? messageId,
  ) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          '[FCM] Notification image request failed: ${response.statusCode}',
        );
        return null;
      }
      final directory = await getTemporaryDirectory();
      final filename = 'fcm_${_notificationId(messageId)}.jpg';
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return FilePathAndroidBitmap(file.path);
    } catch (error) {
      debugPrint('[FCM] Notification image download failed: $error');
      return null;
    }
  }

  static int _notificationId(String? messageId) {
    if (messageId == null || messageId.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
    }

    var hash = 0;
    for (final codeUnit in messageId.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
