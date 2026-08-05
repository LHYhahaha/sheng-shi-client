import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_definition.dart';
import 'analytics_event.dart';
import 'analytics_provider.dart';
import 'analytics_service.dart';

abstract interface class AnalyticsFirstOpenStore {
  Future<bool> markFirstOpenIfNeeded();
}

class SharedPreferencesAnalyticsFirstOpenStore
    implements AnalyticsFirstOpenStore {
  static const _key = 'analytics.first_open_reported.v1';

  @override
  Future<bool> markFirstOpenIfNeeded() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_key) ?? false) {
      return false;
    }
    await preferences.setBool(_key, true);
    return true;
  }
}

/// 将 Flutter 生命周期转为基础埋点事件。
class AnalyticsLifecycleTracker {
  AnalyticsLifecycleTracker({
    required AnalyticsService analytics,
    required AnalyticsFirstOpenStore firstOpenStore,
    DateTime Function()? now,
  }) : _analytics = analytics,
       _firstOpenStore = firstOpenStore,
       _now = now ?? DateTime.now;

  final AnalyticsService _analytics;
  final AnalyticsFirstOpenStore _firstOpenStore;
  final DateTime Function() _now;

  DateTime? _foregroundStartedAt;
  bool _initialized = false;
  bool _backgrounded = false;

  Future<void> onApplicationReady() async {
    if (_initialized) return;
    _initialized = true;
    _foregroundStartedAt = _now();
    if (await _firstOpenStore.markFirstOpenIfNeeded()) {
      await _analytics.track(
        const AnalyticsEvent(AnalyticsDefinitions.appFirstOpen),
      );
    }
    await _analytics.track(
      const AnalyticsEvent(AnalyticsDefinitions.appLaunch, {
        'launch_type': 'cold',
      }),
    );
  }

  Future<void> onLifecycleChanged(AppLifecycleState state) async {
    if (!_initialized) return;
    if (_isBackgroundState(state)) {
      if (_backgrounded) return;
      _backgrounded = true;
      final startedAt = _foregroundStartedAt;
      _foregroundStartedAt = null;
      if (startedAt == null) return;
      await _analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.appExit, {
          'foreground_duration_ms': _now().difference(startedAt).inMilliseconds,
        }),
      );
      return;
    }
    if (state != AppLifecycleState.resumed || !_backgrounded) return;
    _backgrounded = false;
    _foregroundStartedAt = _now();
    await _analytics.track(
      const AnalyticsEvent(AnalyticsDefinitions.appLaunch, {
        'launch_type': 'hot',
      }),
    );
  }

  bool _isBackgroundState(AppLifecycleState state) =>
      state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached ||
      state == AppLifecycleState.hidden;
}

final analyticsFirstOpenStoreProvider = Provider<AnalyticsFirstOpenStore>((
  ref,
) {
  return SharedPreferencesAnalyticsFirstOpenStore();
});

final analyticsLifecycleTrackerProvider = Provider<AnalyticsLifecycleTracker>((
  ref,
) {
  return AnalyticsLifecycleTracker(
    analytics: ref.watch(analyticsServiceProvider),
    firstOpenStore: ref.watch(analyticsFirstOpenStoreProvider),
  );
});
