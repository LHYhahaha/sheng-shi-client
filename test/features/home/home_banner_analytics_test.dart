import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/features/home/application/home_banner_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports each visible banner once per home page session', () async {
    final sink = AnalyticsInMemoryEventSink();
    final tracker = HomeBannerExposureTracker(analytics: _service(sink));
    const dramaBanner = HomeBannerAnalyticsItem(
      bannerId: 'banner-1',
      targetType: 'drama',
      targetDramaId: '636',
    );

    await tracker.trackVisible(dramaBanner);
    await tracker.trackVisible(dramaBanner);

    expect(sink.events, hasLength(1));
    expect(sink.events.single.eventName, 'home_banner_exposure');
    expect(sink.events.single.eventParams, {
      'banner_id': 'banner-1',
      'banner_target_type': 'drama',
      'target_drama_id': '636',
    });

    tracker.beginPageSession();
    await tracker.trackVisible(dramaBanner);
    expect(sink.events, hasLength(2));
  });
}

AnalyticsService _service(AnalyticsInMemoryEventSink sink) {
  return AnalyticsService(
    contextReader: () => const AnalyticsContext(
      platform: 'android',
      appVersion: '1.0.3',
      language: 'en',
    ),
    eventSink: sink,
  );
}
