// import 'dart:async';
// import 'dart:convert';
//
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
// import 'fcm_notification.dart';
//
// const _androidNotificationChannel = AndroidNotificationChannel(
//   'high_importance_channel',
//   'Important notifications',
//   description: 'Notifications sent by NovaShort.',
//   importance: Importance.high,
// );
//
// /// FCM 后台消息入口。必须是顶层函数，且在 [main] 中注册。
// @pragma('vm:entry-point')
// Future<void> fcmBackgroundMessageHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   final notification = FcmNotification.fromRemoteMessage(message);
//   debugPrint(
//     '[FCM] Background message received: '
//     'id=${notification.id}, data=${notification.data}',
//   );
// }
//
// /// 初始化 FCM、打印 Token，并将前台 FCM 消息展示为本地通知。
// ///
// /// 不申请通知权限；项目已有的用户触发授权流程会负责申请权限。Token
// /// 仅输出到 debug log，后续接入后台接口时可在 [_listenForTokenRefresh] 中上报。
// class FcmNotificationService {
//   FcmNotificationService({
//     FirebaseMessaging? messaging,
//     FlutterLocalNotificationsPlugin? localNotifications,
//   }) : _messaging = messaging ?? FirebaseMessaging.instance,
//        _localNotifications =
//            localNotifications ?? FlutterLocalNotificationsPlugin();
//
//   final FirebaseMessaging _messaging;
//   final FlutterLocalNotificationsPlugin _localNotifications;
//
//   StreamSubscription<String>? _tokenRefreshSubscription;
//   StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
//   StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
//   Future<void>? _initialization;
//
//   Future<void> initialize() {
//     return _initialization ??= _initialize();
//   }
//
//   Future<void> _initialize() async {
//     await _initializeLocalNotifications();
//     await _printCurrentToken();
//     _listenForTokenRefresh();
//     _listenForMessages();
//     await _handleInitialMessage();
//   }
//
//   Future<void> _initializeLocalNotifications() async {
//     const settings = InitializationSettings(
//       android: AndroidInitializationSettings('ic_notification'),
//       iOS: DarwinInitializationSettings(
//         requestAlertPermission: false,
//         requestBadgePermission: false,
//         requestSoundPermission: false,
//       ),
//     );
//     await _localNotifications.initialize(
//       settings: settings,
//       onDidReceiveNotificationResponse: _handleLocalNotificationTap,
//     );
//     await _localNotifications
//         .resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin
//         >()
//         ?.createNotificationChannel(_androidNotificationChannel);
//   }
//
//   Future<void> _printCurrentToken() async {
//     try {
//       final token = await _messaging.getToken();
//       if (token == null || token.isEmpty) {
//         debugPrint('[FCM] Token is unavailable. It may be pending APNs setup.');
//         return;
//       }
//       debugPrint('[FCM] Token: $token');
//     } catch (error, stackTrace) {
//       debugPrint('[FCM] Failed to get token: $error');
//       debugPrintStack(stackTrace: stackTrace);
//     }
//   }
//
//   void _listenForTokenRefresh() {
//     _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
//       (token) => debugPrint('[FCM] Token refreshed: $token'),
//       onError: (Object error, StackTrace stackTrace) {
//         debugPrint('[FCM] Token refresh failed: $error');
//         debugPrintStack(stackTrace: stackTrace);
//       },
//     );
//   }
//
//   void _listenForMessages() {
//     _foregroundMessageSubscription ??= FirebaseMessaging.onMessage.listen(
//       _handleForegroundMessage,
//       onError: (Object error, StackTrace stackTrace) {
//         debugPrint('[FCM] Foreground message failed: $error');
//         debugPrintStack(stackTrace: stackTrace);
//       },
//     );
//     _messageOpenedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
//       _handleMessageOpened,
//       onError: (Object error, StackTrace stackTrace) {
//         debugPrint('[FCM] Message-open event failed: $error');
//         debugPrintStack(stackTrace: stackTrace);
//       },
//     );
//   }
//
//   Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     final notification = FcmNotification.fromRemoteMessage(message);
//     debugPrint(
//       '[FCM] Foreground message received: '
//       'id=${notification.id}, data=${notification.data}',
//     );
//     if (!notification.hasDisplayContent) return;
//
//     await _localNotifications.show(
//       id: _notificationId(notification.id),
//       title: notification.title,
//       body: notification.body,
//       notificationDetails: const NotificationDetails(
//         android: AndroidNotificationDetails(
//           'high_importance_channel',
//           'Important notifications',
//           channelDescription: 'Notifications sent by NovaShort.',
//           importance: Importance.high,
//           priority: Priority.high,
//           icon: 'ic_notification',
//         ),
//         iOS: DarwinNotificationDetails(
//           presentAlert: true,
//           presentBadge: true,
//           presentSound: true,
//         ),
//       ),
//       payload: jsonEncode({
//         'id': notification.id,
//         'actionUrl': notification.actionUrl,
//         'data': notification.data,
//       }),
//     );
//   }
//
//   Future<void> _handleInitialMessage() async {
//     final message = await _messaging.getInitialMessage();
//     if (message != null) _handleMessageOpened(message);
//   }
//
//   void _handleMessageOpened(RemoteMessage message) {
//     final notification = FcmNotification.fromRemoteMessage(message);
//     debugPrint(
//       '[FCM] Remote notification opened: '
//       'id=${notification.id}, actionUrl=${notification.actionUrl}, '
//       'data=${notification.data}',
//     );
//   }
//
//   void _handleLocalNotificationTap(NotificationResponse response) {
//     debugPrint('[FCM] Local notification opened: payload=${response.payload}');
//   }
//
//   static int _notificationId(String? messageId) {
//     if (messageId == null || messageId.isEmpty) {
//       return DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
//     }
//
//     var hash = 0;
//     for (final codeUnit in messageId.codeUnits) {
//       hash = (hash * 31 + codeUnit) & 0x7fffffff;
//     }
//     return hash;
//   }
// }
