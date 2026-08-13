import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'analytics_definition.dart';
import 'analytics_event.dart';
import 'analytics_provider.dart';
import 'analytics_service.dart';

abstract interface class AnalyticsFirstOpenStore {
  Future<bool> markFirstOpenIfNeeded();
}

/// 协调冷启动事件与首个页面事件的顺序。
///
/// 页面可在路由首帧写入页面上下文，但必须等 `app_launch` 的公共参数就绪后，
/// 才允许真正上报 `page_view`。
class AnalyticsStartupGate {
  AnalyticsStartupGate({bool isReady = false}) {
    if (isReady) _ready.complete();
  }

  final Completer<void> _ready = Completer<void>();

  Future<void> get ready => _ready.future;

  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }
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
    AnalyticsStartupGate? startupGate,
    DateTime Function()? now,
  }) : _analytics = analytics,
       _firstOpenStore = firstOpenStore,
       _startupGate = startupGate ?? AnalyticsStartupGate(isReady: true),
       _now = now ?? DateTime.now;

  final AnalyticsService _analytics;
  final AnalyticsFirstOpenStore _firstOpenStore;
  final AnalyticsStartupGate _startupGate;
  final DateTime Function() _now;

  DateTime? _foregroundStartedAt;
  bool _initialized = false;
  bool _backgrounded = false;

  Future<void> onApplicationReady() async {
    if (_initialized) return;
    _initialized = true;
    _foregroundStartedAt = _now();
    try {
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
    } finally {
      // 即使埋点 Sink 发生异常，也不能永久阻塞首个页面事件。
      _startupGate.markReady();
    }
  }

  Future<void> onLifecycleChanged(AppLifecycleState state) async {
    if (!_initialized) {
      debugPrint(
        '[Analytics] Lifecycle ignored before app_launch is initialized: ${state.name}',
      );
      return;
    }
    if (_isBackgroundState(state)) {
      if (_backgrounded) {
        debugPrint(
          '[Analytics] Lifecycle background already recorded: ${state.name}',
        );
        return;
      }
      _backgrounded = true;
      final startedAt = _foregroundStartedAt;
      _foregroundStartedAt = null;
      if (startedAt == null) {
        debugPrint(
          '[Analytics] Lifecycle background has no foreground start time.',
        );
        return;
      }
      debugPrint('[Analytics] Reporting app_exit for lifecycle: ${state.name}');
      await _analytics.track(
        AnalyticsEvent(AnalyticsDefinitions.appExit, {
          'foreground_duration_ms': _now().difference(startedAt).inMilliseconds,
        }),
      );
      return;
    }
    if (state != AppLifecycleState.resumed || !_backgrounded) {
      return;
    }
    _backgrounded = false;
    _foregroundStartedAt = _now();
    debugPrint(
      '[Analytics] Reporting app_launch(hot) after foreground return.',
    );
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

final analyticsStartupGateProvider = Provider<AnalyticsStartupGate>((ref) {
  return AnalyticsStartupGate();
});

final analyticsLifecycleTrackerProvider = Provider<AnalyticsLifecycleTracker>((
  ref,
) {
  return AnalyticsLifecycleTracker(
    analytics: ref.watch(analyticsServiceProvider),
    firstOpenStore: ref.watch(analyticsFirstOpenStoreProvider),
    startupGate: ref.watch(analyticsStartupGateProvider),
  );
});
