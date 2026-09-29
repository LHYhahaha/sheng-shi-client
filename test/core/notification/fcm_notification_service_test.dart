import 'package:drama_client/core/notification/fcm_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getFcmTokenWhenApnsReady', () {
    test(
      'does not request an FCM token before APNs is available on iOS',
      () async {
        var fcmTokenRequests = 0;

        final token = await getFcmTokenWhenApnsReady(
          isApplePlatform: true,
          apnsTokenReader: () async => null,
          fcmTokenReader: () async {
            fcmTokenRequests++;
            return 'fcm-token';
          },
          maximumApnsTokenAttempts: 1,
        );

        expect(token, isNull);
        expect(fcmTokenRequests, 0);
      },
    );

    test('requests an FCM token once APNs becomes available on iOS', () async {
      var apnsTokenReads = 0;
      var fcmTokenRequests = 0;

      final token = await getFcmTokenWhenApnsReady(
        isApplePlatform: true,
        apnsTokenReader: () async {
          apnsTokenReads++;
          return apnsTokenReads == 2 ? 'apns-token' : null;
        },
        fcmTokenReader: () async {
          fcmTokenRequests++;
          return 'fcm-token';
        },
        maximumApnsTokenAttempts: 2,
        wait: (_) async {},
      );

      expect(token, 'fcm-token');
      expect(fcmTokenRequests, 1);
    });
  });
}
