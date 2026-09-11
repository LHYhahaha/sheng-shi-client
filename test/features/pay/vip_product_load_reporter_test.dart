import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/features/pay/application/vip_product_load_reporter.dart';
import 'package:drama_client/features/pay/domain/vip_product_load_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'classifies empty backend data, missing billing data and partial success',
    () {
      expect(
        VipProductLoadResult.loaded(sourceCount: 0, displayCount: 0).result,
        'empty',
      );
      expect(
        VipProductLoadResult.loaded(sourceCount: 3, displayCount: 0).result,
        'google_request_failed',
      );
      expect(
        VipProductLoadResult.loaded(sourceCount: 3, displayCount: 2).result,
        'success',
      );
    },
  );

  testWidgets('reports after frame once per attempt, including retry', (
    tester,
  ) async {
    final sink = AnalyticsInMemoryEventSink();
    final service = AnalyticsService(
      contextReader: () => const AnalyticsContext(
        platform: 'android',
        appVersion: '1',
        language: 'en',
      ),
      eventSink: sink,
    );
    final reporter = VipProductLoadReporter();
    void report(VipProductLoadResult attempt, {bool current = true}) {
      tester.binding.scheduleFrame();
      reporter.reportAfterFrame(
        attempt: attempt,
        productCount: 2,
        isCurrent: () => current,
        analytics: () => service,
        rechargePopupType: 'vip_only',
      );
    }

    final success = VipProductLoadResult('success');
    report(success);
    report(success);
    expect(sink.events, isEmpty);
    await tester.pump();
    expect(sink.events.single.eventName, 'vip_product_load_result');
    expect(sink.events.single.eventParams, {
      'product_load_result': 'success',
      'product_count': 2,
      'recharge_popup_type': 'vip_only',
    });
    for (final result in ['empty', 'request_failed', 'google_request_failed']) {
      report(VipProductLoadResult(result));
      await tester.pump();
      expect(sink.events.last.eventParams['product_load_result'], result);
      expect(sink.events.last.eventParams['product_count'], 0);
    }
    report(VipProductLoadResult('success'));
    await tester.pump();
    expect(sink.events, hasLength(5));
    report(VipProductLoadResult('success'), current: false);
    await tester.pump();
    expect(sink.events, hasLength(5));
  });
}
