import 'package:drama_client/core/notification/fcm_notification.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FcmNotification', () {
    test('uses FCM notification fields before data fallbacks', () {
      final sentTime = DateTime(2026, 7, 27, 10, 30);
      final message = RemoteMessage.fromMap({
        'messageId': 'fcm-1',
        'sentTime': sentTime.millisecondsSinceEpoch,
        'threadId': 'episode-updates',
        'data': {
          'id': 'server-id',
          'title': 'Data title',
          'body': 'Data body',
          'deep_link': 'drama://detail/42',
        },
        'notification': {
          'title': ' New episode ',
          'body': ' Watch now ',
          'android': {
            'channelId': 'drama_updates',
            'imageUrl': 'https://example.com/cover.jpg',
          },
        },
      });

      final notification = FcmNotification.fromRemoteMessage(message);

      expect(notification.id, 'fcm-1');
      expect(notification.title, 'New episode');
      expect(notification.body, 'Watch now');
      expect(notification.imageUrl, 'https://example.com/cover.jpg');
      expect(notification.actionUrl, 'drama://detail/42');
      expect(notification.sentTime, sentTime);
      expect(notification.channelId, 'drama_updates');
      expect(notification.threadId, 'episode-updates');
      expect(notification.data['id'], 'server-id');
      expect(notification.hasDisplayContent, isTrue);
    });

    test('supports data-only FCM messages and ignores blank values', () {
      final message = RemoteMessage.fromMap({
        'data': {
          'id': 'push-42',
          'title': '  Reward available  ',
          'content': '  Claim your points  ',
          'image_url': ' https://example.com/reward.jpg ',
          'url': ' https://example.com/rewards ',
          'count': 3,
        },
      });

      final notification = FcmNotification.fromRemoteMessage(message);

      expect(notification.id, 'push-42');
      expect(notification.title, 'Reward available');
      expect(notification.body, 'Claim your points');
      expect(notification.imageUrl, 'https://example.com/reward.jpg');
      expect(notification.actionUrl, 'https://example.com/rewards');
      expect(notification.data['count'], '3');
    });

    test(
      'uses the shared data image before platform-specific image fields',
      () {
        final message = RemoteMessage.fromMap({
          'data': {'image_url': 'https://example.com/shared.jpg'},
          'notification': {
            'android': {'imageUrl': 'https://example.com/android.jpg'},
            'apple': {'imageUrl': 'https://example.com/ios.jpg'},
          },
        });

        final notification = FcmNotification.fromRemoteMessage(message);

        expect(notification.imageUrl, 'https://example.com/shared.jpg');
      },
    );

    test('supports icon_url from the notification dump contract', () {
      final message = RemoteMessage.fromMap({
        'data': {
          'dump_type': 'drama',
          'drama_id': '10086',
          'icon_url': 'https://example.com/drama-cover.jpg',
        },
      });

      final notification = FcmNotification.fromRemoteMessage(message);

      expect(notification.data['dump_type'], 'drama');
      expect(notification.data['drama_id'], '10086');
      expect(notification.imageUrl, 'https://example.com/drama-cover.jpg');
    });

    test(
      'does not report display content when all display fields are blank',
      () {
        final message = RemoteMessage.fromMap({
          'data': {'title': ' ', 'body': ''},
        });

        final notification = FcmNotification.fromRemoteMessage(message);

        expect(notification.title, isNull);
        expect(notification.body, isNull);
        expect(notification.hasDisplayContent, isFalse);
      },
    );
  });
}
