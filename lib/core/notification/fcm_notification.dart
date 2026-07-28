import 'package:firebase_messaging/firebase_messaging.dart';

/// 可供应用界面和本地通知直接展示的 FCM 推送消息。
///
/// 服务端可以将展示内容放在 FCM 的 `notification` 字段，也可以在
/// `data` 中传递 `title`、`body`（或 `content`）和 `imageUrl`。
/// 其余 `data` 会原样保留，供点击通知后的业务跳转使用。
class FcmNotification {
  const FcmNotification({
    required this.data,
    this.id,
    this.title,
    this.body,
    this.imageUrl,
    this.actionUrl,
    this.sentTime,
    this.channelId,
    this.threadId,
  });

  /// FCM 分配的消息 ID；若未提供，则使用服务端 data 中的 `id`。
  final String? id;

  /// 用于通知标题或应用内消息卡片的标题。
  final String? title;

  /// 用于通知正文或应用内消息卡片的正文。
  final String? body;

  /// 通知配图地址。优先使用 FCM Android notification image。
  final String? imageUrl;

  /// 点击通知后可打开的深链或网页地址。
  final String? actionUrl;

  /// 服务端发送消息的时间。
  final DateTime? sentTime;

  /// Android 通知渠道 ID。
  final String? channelId;

  /// iOS 通知分组 ID。
  final String? threadId;

  /// 服务端附加数据，供业务层根据类型、剧集 ID 等信息处理跳转。
  final Map<String, String> data;

  /// 消息是否包含可展示的标题或正文。
  bool get hasDisplayContent => title != null || body != null;

  /// 从 Firebase SDK 的原始消息构建展示模型。
  factory FcmNotification.fromRemoteMessage(RemoteMessage message) {
    final data = Map<String, String>.unmodifiable(
      message.data.map((key, value) => MapEntry(key, value.toString())),
    );
    final notification = message.notification;
    final android = notification?.android;

    return FcmNotification(
      id: _firstNonBlank(message.messageId, data['id'], data['messageId']),
      title: _firstNonBlank(notification?.title, data['title']),
      body: _firstNonBlank(notification?.body, data['body'], data['content']),
      imageUrl: _firstNonBlank(
        android?.imageUrl,
        data['imageUrl'],
        data['image_url'],
        data['image'],
      ),
      actionUrl: _firstNonBlank(
        data['deepLink'],
        data['deep_link'],
        data['url'],
        data['link'],
      ),
      sentTime: message.sentTime,
      channelId: android?.channelId,
      threadId: message.threadId,
      data: data,
    );
  }

  static String? _firstNonBlank(
    String? first, [
    String? second,
    String? third,
    String? fourth,
  ]) {
    for (final value in [first, second, third, fourth]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
