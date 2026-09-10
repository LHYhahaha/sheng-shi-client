import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drama_client/core/analytics/analytics_definition.dart';
import 'package:drama_client/core/analytics/analytics_event.dart';
import 'package:drama_client/core/analytics/analytics_provider.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/core/auth/user_info_store.dart';
import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_client_provider.dart';
import 'package:drama_client/features/entitlement/application/entitlement_controller.dart';
import 'package:drama_client/features/entitlement/data/entitlement_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/recording_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final nestedId in <Object?>['2072231756014030848', '', null]) {
    test('uploads exact string userId when nested ID is $nestedId', () async {
      SharedPreferences.setMockInitialValues({});
      const expectedId = '2072231756014030848';
      final adapter = RecordingHttpAdapter(
        responses: {
          'GET /api/user/entitlements': RecordingHttpResponse(
            body: {
              'code': 0,
              'message': 'Success',
              'data': {
                if (nestedId != expectedId) 'userId': expectedId,
                'membership': {
                  'isMember': false,
                  'membershipExpiresAt': '2026-09-08T03:49:22Z',
                },
                'playback': {
                  'autoUnlockEnabled': false,
                  'pendingOperationId': '',
                  'unlockedEpisodeNos': <int>[],
                },
                'point': {'totalPointBalance': '142'},
                'userInfo': {
                  'isGuest': false,
                  'language': 'en',
                  'nickname': 'Test user',
                  'showId': '293944466',
                  'status': 1,
                  'userId': nestedId,
                },
                'wallet': {'bonusBalance': '1510', 'coinBalance': '167'},
              },
            },
          ),
          'POST /api/analytics/event/batch-upload': const RecordingHttpResponse(
            body: {'code': 0, 'data': {}, 'message': 'Success'},
          ),
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = ApiClient(dio: dio, accessTokenReader: () => 'test-token');
      final sink = AnalyticsBatchUploadEventSink(
        apiClientReader: () => client,
        uploadsEnabled: false,
      );
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          useRemoteEntitlementApiProvider.overrideWithValue(true),
          analyticsEventSinkProvider.overrideWithValue(sink),
        ],
      );
      addTearDown(() {
        container.dispose();
        sink.dispose();
        dio.close();
      });
      await container.read(userInfoStoreProvider.notifier).waitForHydration();
      // Create the service before user information arrives, like cold startup.
      final analytics = container.read(analyticsServiceProvider);
      expect(container.read(analyticsContextProvider).userId, isNull);
      expect(
        await container
            .read(entitlementControllerProvider.notifier)
            .refreshFromServer(),
        isTrue,
      );
      expect(container.read(entitlementControllerProvider).userId, expectedId);
      if (nestedId == expectedId) {
        expect(container.read(userInfoStoreProvider).userId, expectedId);
      }
      await analytics.track(
        const AnalyticsEvent(AnalyticsDefinitions.appLaunch, {
          'launch_type': 'cold',
        }),
      );
      await sink.enableUploads();
      final request = adapter.requests.singleWhere(
        (request) => request.path == '/api/analytics/event/batch-upload',
      );
      final body = jsonDecode(request.data! as String) as Map<String, dynamic>;
      final common = (body['events'] as List).single['commonParams'] as Map;
      expect(common['userId'], expectedId);
      expect(common['userId'], isA<String>());
    });
  }
}
