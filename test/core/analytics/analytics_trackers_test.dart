import 'package:drama_client/core/analytics/analytics_context.dart';
import 'package:drama_client/core/analytics/analytics_lifecycle_tracker.dart';
import 'package:drama_client/core/analytics/analytics_page_context.dart';
import 'package:drama_client/core/analytics/analytics_page_tracker.dart';
import 'package:drama_client/core/analytics/analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  test(
    'lifecycle emits first open, cold launch, exit and hot launch',
    () async {
      final sink = AnalyticsInMemoryEventSink();
      var now = DateTime.utc(2026, 8, 4, 0, 0);
      final tracker = AnalyticsLifecycleTracker(
        analytics: _service(sink, () => now),
        firstOpenStore: _FirstOpenStore(),
        now: () => now,
      );

      await tracker.onApplicationReady();
      now = now.add(const Duration(seconds: 3));
      await tracker.onLifecycleChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 2));
      await tracker.onLifecycleChanged(AppLifecycleState.resumed);

      expect(sink.events.map((event) => event.eventName), [
        'app_first_open',
        'app_launch',
        'app_exit',
        'app_launch',
      ]);
      expect(sink.events[2].eventParams['foreground_duration_ms'], 3000);
      expect(sink.events[3].eventParams['launch_type'], 'hot');
    },
  );

  test('page tracker emits leave before entering the next page', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sink = AnalyticsInMemoryEventSink();
    var now = DateTime.utc(2026, 8, 4, 0, 0);
    final tracker = AnalyticsPageTracker(
      analytics: _service(
        sink,
        () => now,
        contextReader: () {
          final page = container.read(analyticsPageContextProvider);
          return AnalyticsContext(
            platform: 'android',
            appVersion: '1.0.3',
            language: 'zh-CN',
            pageName: page.currentPage,
            previousPage: page.previousPage,
          );
        },
      ),
      pageContext: container.read(analyticsPageContextProvider.notifier),
      now: () => now,
    );

    await tracker.push(AnalyticsPageNames.home);
    now = now.add(const Duration(seconds: 4));
    await tracker.push(AnalyticsPageNames.search);

    expect(sink.events.map((event) => event.eventName), [
      'page_view',
      'page_leave',
      'page_view',
    ]);
    expect(sink.events[1].eventParams['stay_duration_ms'], 4000);
    expect(
      sink.events[2].commonParams.toJson()['previous_page'],
      AnalyticsPageNames.home,
    );
  });

  test('page tracker emits leave immediately for a popped page', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sink = AnalyticsInMemoryEventSink();
    var now = DateTime.utc(2026, 8, 4, 0, 0);
    final tracker = AnalyticsPageTracker(
      analytics: _service(sink, () => now),
      pageContext: container.read(analyticsPageContextProvider.notifier),
      now: () => now,
    );

    await tracker.push(AnalyticsPageNames.vipPurchase);
    now = now.add(const Duration(seconds: 2));
    await tracker.pop(AnalyticsPageNames.vipPurchase);

    expect(sink.events.map((event) => event.eventName), [
      'page_view',
      'page_leave',
    ]);
    expect(sink.events.last.eventParams['stay_duration_ms'], 2000);
  });

  test(
    'page tracker restores the prior page from its navigation stack',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sink = AnalyticsInMemoryEventSink();
      final tracker = AnalyticsPageTracker(
        analytics: _service(sink, DateTime.now),
        pageContext: container.read(analyticsPageContextProvider.notifier),
      );

      await tracker.push(AnalyticsPageNames.my);
      await tracker.push(AnalyticsPageNames.vipPurchase);
    await tracker.pop(AnalyticsPageNames.vipPurchase);

    expect(tracker.pageStack, [AnalyticsPageNames.my]);
    expect(sink.events.last.eventName, 'page_view');
    expect(
      container.read(analyticsPageContextProvider).currentPage,
      AnalyticsPageNames.my,
    );
    },
  );

  test('maps confirmed profile, wallet, recharge and login page names', () {
    expect(analyticsPageNameForRoute('profile'), AnalyticsPageNames.my);
    expect(analyticsPageNameForRoute('wallet'), AnalyticsPageNames.wallet);
    expect(analyticsPageNameForRoute('store'), AnalyticsPageNames.coinRecharge);
    expect(analyticsPageNameForRoute('auth'), AnalyticsPageNames.login);
  });
}

AnalyticsService _service(
  AnalyticsInMemoryEventSink sink,
  DateTime Function() now, {
  AnalyticsContext Function()? contextReader,
}) {
  var eventIndex = 0;
  return AnalyticsService(
    contextReader:
        contextReader ??
        () => const AnalyticsContext(
          platform: 'android',
          appVersion: '1.0.3',
          language: 'zh-CN',
        ),
    eventSink: sink,
    clock: now,
    eventIdGenerator: () => 'evt-${eventIndex++}',
  );
}

class _FirstOpenStore implements AnalyticsFirstOpenStore {
  bool _first = true;

  @override
  Future<bool> markFirstOpenIfNeeded() async {
    final result = _first;
    _first = false;
    return result;
  }
}
