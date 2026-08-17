import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/core/modal/app_modal_analytics_tracker.dart';
import 'package:drama_client/core/modal/app_modal_request.dart';
import 'package:drama_client/core/modal/app_modal_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses popup_show parameters for popup_close', () async {
    final sink = AnalyticsInMemoryEventSink();
    final tracker = AppModalAnalyticsTracker(
      AnalyticsService(
        contextReader: () => const AnalyticsContext(
          platform: 'android',
          appVersion: '1.0.3',
          language: 'en',
        ),
        eventSink: sink,
      ),
    );
    final request = FeatureAppModalRequest(
      requestId: 'unlock-1',
      source: AppModalSource.player,
      channel: 'player.coin_unlock',
      analyticsPopupShowParameters: const {
        'popup_name': 'episode_unlock_confirm_popup',
        'drama_id': '99',
        'episode_id': '100',
        'required_coin_amount': 60,
      },
    );

    tracker.onPresented(request);
    tracker.onClosed(request);
    await Future<void>.delayed(Duration.zero);

    expect(sink.events, hasLength(2));
    expect(sink.events[1].eventParams, sink.events[0].eventParams);
  });
}
