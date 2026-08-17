import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:drama_client/features/ad_unlock/application/ad_unlock_analytics_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a self-hosted ad material click to its session identifiers', () {
    expect(
      adMaterialClickParameters(adSessionId: 'session-1', adMaterialId: '300'),
      {
        'element_name': 'ad_material',
        'ad_session_id': 'session-1',
        'ad_material_id': '300',
      },
    );
  });

  test(
    'reports one start and a qualified end for a visible ad session',
    () async {
      final sink = AnalyticsInMemoryEventSink();
      final tracker = AdUnlockAnalyticsTracker(
        analytics: AnalyticsService(
          contextReader: () => const AnalyticsContext(
            platform: 'android',
            appVersion: '1.0.3',
            language: 'en',
          ),
          eventSink: sink,
        ),
        adSessionId: 'ad-session-1',
        adMaterialId: '300',
        dramaId: '100',
        episodeId: '200',
      );

      await tracker.markMaterialVisible();
      await tracker.finish(
        watchedDuration: const Duration(seconds: 12),
        reachedRequiredWatchTime: true,
      );
      await tracker.finish(
        watchedDuration: const Duration(seconds: 12),
        reachedRequiredWatchTime: true,
      );

      expect(sink.events.map((event) => event.eventName), [
        'ad_view_start',
        'ad_view_end',
      ]);
      expect(sink.events.last.eventParams, {
        'ad_session_id': 'ad-session-1',
        'ad_material_id': '300',
        'drama_id': '100',
        'episode_id': '200',
        'ad_view_duration_ms': 12000,
        'ad_view_result': 'qualified',
      });
    },
  );

  test(
    'prefers load failure over early exit when ending an unseen ad',
    () async {
      final sink = AnalyticsInMemoryEventSink();
      final tracker = AdUnlockAnalyticsTracker(
        analytics: AnalyticsService(
          contextReader: () => const AnalyticsContext(
            platform: 'android',
            appVersion: '1.0.3',
            language: 'en',
          ),
          eventSink: sink,
        ),
        adSessionId: 'ad-session-2',
        adMaterialId: '301',
        dramaId: '101',
        episodeId: '201',
      );

      await tracker.finish(
        watchedDuration: Duration.zero,
        materialLoadFailed: true,
      );

      expect(sink.events.map((event) => event.eventName), ['ad_view_end']);
      expect(sink.events.single.eventParams['ad_view_result'], 'load_failed');
    },
  );

  test('deduplicates entry exposure by drama episode and material', () async {
    final sink = AnalyticsInMemoryEventSink();
    final tracker = AdUnlockEntryExposureTracker(
      analytics: AnalyticsService(
        contextReader: () => const AnalyticsContext(
          platform: 'android',
          appVersion: '1.0.3',
          language: 'en',
        ),
        eventSink: sink,
      ),
    );

    await tracker.reportIfVisible(
      dramaId: '100',
      episodeId: '200',
      dramaAccessType: 'normal',
      adMaterialId: '300',
    );
    await tracker.reportIfVisible(
      dramaId: '100',
      episodeId: '200',
      dramaAccessType: 'normal',
      adMaterialId: '300',
    );
    await tracker.reportIfVisible(
      dramaId: '100',
      episodeId: '200',
      dramaAccessType: 'normal',
      adMaterialId: '301',
    );

    expect(sink.events.map((event) => event.eventName), [
      'ad_unlock_entry_exposure',
      'ad_unlock_entry_exposure',
    ]);
  });
}
