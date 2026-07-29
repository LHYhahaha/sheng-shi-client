import 'package:firebase_messaging/firebase_messaging.dart';

/// 可供应用界面和本地通知直接展示的 FCM 推送消息。
///
/// 服务端将展示内容放在 FCM 的 `notification` 字段，并在 `data` 中传递
/// `type`、跳转参数和跨平台统一的 `image_url`。
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

  /// 通知配图地址。优先使用跨平台 data 中的 `image_url`。
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
    final apple = notification?.apple;

    return FcmNotification(
      id: _firstNonBlank(message.messageId, data['id'], data['messageId']),
      title: _firstNonBlank(notification?.title, data['title']),
      body: _firstNonBlank(notification?.body, data['body'], data['content']),
      imageUrl: _firstNonBlank(
        data['image_url'],
        data['imageUrl'],
        android?.imageUrl,
        apple?.imageUrl,
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

  /// 从本地通知点击时保存的 payload 还原消息。
  factory FcmNotification.fromPayload(Map<String, dynamic> payload) {
    final rawData = payload['data'];
    final data = Map<String, String>.unmodifiable(
      rawData is Map
          ? rawData.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
    );
    return FcmNotification(
      id: _firstNonBlank(payload['id']?.toString()),
      title: _firstNonBlank(payload['title']?.toString()),
      body: _firstNonBlank(payload['body']?.toString()),
      imageUrl: _firstNonBlank(payload['imageUrl']?.toString()),
      actionUrl: _firstNonBlank(payload['actionUrl']?.toString()),
      data: data,
    );
  }

  Map<String, Object?> toPayload() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'data': data,
    };
  }

  static String? _firstNonBlank(
    String? first, [
    String? second,
    String? third,
    String? fourth,
    String? fifth,
  ]) {
    for (final value in [first, second, third, fourth, fifth]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
