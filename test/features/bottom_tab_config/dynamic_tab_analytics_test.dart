import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/features/bottom_tab_config/application/dynamic_tab_analytics.dart';
import 'package:drama_client/features/bottom_tab_config/data/dto/bottom_tab_response_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports a dynamic tab only once during the app lifecycle', () async {
    final sink = AnalyticsInMemoryEventSink();
    final tracker = DynamicTabExposureTracker(analytics: _service(sink));
    const tab = BottomTabDto(
      h5Url: 'https://example.com/member',
      nameI18nKey: 'member',
      normalIconUrl: '',
      replaceTab: 'MEMBER_TAB',
      selectedIconUrl: '',
      tabConfigId: 'tab-config-1',
    );

    await tracker.trackVisible(tab);
    await tracker.trackVisible(tab);

    expect(sink.events, hasLength(1));
    expect(sink.events.single.eventName, 'dynamic_tab_exposure');
    expect(sink.events.single.eventParams, {
      'tab_config_id': 'tab-config-1',
      'replace_tab_key': 'member_tab',
    });
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
