import 'dart:async';
import 'dart:convert';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_event.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adjust_service.dart';

/// 客户端可上报的 Adjust 事件 token。
abstract final class AdjustEventTokens {
  static const appFirstOpen = 'xklyoy';
  static const dramaPlayStart = 'x7p5qa';
  static const homeFirstView = '37fm6a';
  static const checkoutStart = 'm8l7ax';
}

/// 隔离 Adjust SDK，便于事件规则独立测试。
abstract interface class AdjustEventClient {
  void track(String eventToken, {Map<String, String> parameters = const {}});

  Future<void> recoverPendingEvents();
}

class AdjustSdkEventClient implements AdjustEventClient {
  AdjustSdkEventClient({
    AdjustService? service,
    AdjustPendingEventStore? pendingEventStore,
  }) : _service = service ?? AdjustService(),
       _pendingEventStore =
           pendingEventStore ?? SharedPreferencesAdjustPendingEventStore() {
    _service.eventResults.listen(_handleEventResult);
  }

  final AdjustService _service;
  final AdjustPendingEventStore _pendingEventStore;
  bool _isFlushing = false;
  bool _flushRequestedWhileBusy = false;

  @override
  void track(String eventToken, {Map<String, String> parameters = const {}}) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      debugPrint(
        '[Adjust] Event skipped: token=$eventToken '
        'platform=${defaultTargetPlatform.name}.',
      );
      return;
    }
    debugPrint(
      '[Adjust] Event requested: token=$eventToken '
      'parameters=$parameters.',
    );
    _service.initialize();
    unawaited(_enqueueAndFlush(eventToken, parameters));
  }

  Future<void> _enqueueAndFlush(
    String eventToken,
    Map<String, String> parameters,
  ) async {
    try {
      final pending = AdjustPendingEvent.create(
        eventToken: eventToken,
        parameters: parameters,
      );
      await _pendingEventStore.enqueue(pending);
      debugPrint(
        '[Adjust] Event persisted locally: token=$eventToken id=${pending.id} '
        'parameters=${pending.parameters}.',
      );
      await _flushPendingEvents();
    } catch (error, stackTrace) {
      debugPrint('[Adjust] Pending event enqueue failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> recoverPendingEvents() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    debugPrint('[Adjust] Pending event recovery requested at startup.');
    _service.initialize();
    await _flushPendingEvents();
  }

  Future<void> _flushPendingEvents() async {
    if (_isFlushing) {
      _flushRequestedWhileBusy = true;
      debugPrint(
        '[Adjust] Pending event dispatch already in progress; '
        'another pass will run afterwards.',
      );
      return;
    }
    do {
      _isFlushing = true;
      _flushRequestedWhileBusy = false;
      try {
        final pendingEvents = await _pendingEventStore.readAll();
        debugPrint(
          '[Adjust] Pending event dispatch started: '
          'count=${pendingEvents.length}, '
          'sessionConfirmed=${_service.isSessionConfirmed}.',
        );
        if (pendingEvents.isEmpty) {
          debugPrint('[Adjust] No locally pending events to dispatch.');
          continue;
        }
        for (final pending in pendingEvents) {
          final event = AdjustEvent(pending.eventToken)
            ..callbackId = pending.id
            // 同一个本地事件在进程重启前可能被再次派发；交由 SDK 去重。
            ..deduplicationId = pending.id;
          pending.parameters.forEach(event.addCallbackParameter);
          debugPrint(
            '[Adjust] Calling native Adjust.trackEvent: '
            'token=${pending.eventToken} id=${pending.id} '
            'parameters=${pending.parameters}.',
          );
          Adjust.trackEvent(event);
          debugPrint(
            '[Adjust] Native Adjust.trackEvent returned: '
            'token=${pending.eventToken} id=${pending.id}; '
            'waiting for native success/failure callback.',
          );
        }
      } catch (error, stackTrace) {
        debugPrint('[Adjust] Pending event flush failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        _isFlushing = false;
      }
    } while (_flushRequestedWhileBusy);
  }

  void _handleEventResult(AdjustEventResult result) {
    final callbackId = result.callbackId;
    if (callbackId == null || callbackId.isEmpty) return;
    if (result.isSuccess) {
      debugPrint(
        '[Adjust] Event delivery succeeded: id=$callbackId; '
        'removing local fallback.',
      );
      unawaited(_pendingEventStore.remove(callbackId));
      return;
    }
    debugPrint(
      '[Adjust] Event callback failure: id=$callbackId '
      'willRetry=${result.willRetry}; keeping local fallback.',
    );
  }
}

abstract interface class AdjustHomeFirstViewStore {
  Future<bool> markReportedIfNeeded();
}

abstract interface class AdjustPendingEventStore {
  Future<void> enqueue(AdjustPendingEvent event);
  Future<List<AdjustPendingEvent>> readAll();
  Future<void> remove(String id);
}

class SharedPreferencesAdjustPendingEventStore
    implements AdjustPendingEventStore {
  static const _storageKey = 'adjust.pending_events.v1';

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<void> enqueue(AdjustPendingEvent event) async {
    final preferences = await _preferences;
    final events = await readAll();
    await preferences.setString(
      _storageKey,
      jsonEncode([...events.map((item) => item.toJson()), event.toJson()]),
    );
  }

  @override
  Future<List<AdjustPendingEvent>> readAll() async {
    final raw = (await _preferences).getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (value) =>
                AdjustPendingEvent.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> remove(String id) async {
    final preferences = await _preferences;
    final remaining = (await readAll())
        .where((event) => event.id != id)
        .toList();
    if (remaining.isEmpty) {
      await preferences.remove(_storageKey);
      return;
    }
    await preferences.setString(
      _storageKey,
      jsonEncode(remaining.map((event) => event.toJson()).toList()),
    );
  }
}

class AdjustPendingEvent {
  const AdjustPendingEvent({
    required this.id,
    required this.eventToken,
    required this.parameters,
  });

  factory AdjustPendingEvent.create({
    required String eventToken,
    required Map<String, String> parameters,
  }) => AdjustPendingEvent(
    id: '${DateTime.now().microsecondsSinceEpoch}-${Object().hashCode}',
    eventToken: eventToken,
    parameters: Map.unmodifiable(parameters),
  );

  factory AdjustPendingEvent.fromJson(Map<String, dynamic> json) =>
      AdjustPendingEvent(
        id: json['id'] as String,
        eventToken: json['eventToken'] as String,
        parameters: Map<String, String>.from(
          json['parameters'] as Map? ?? const {},
        ),
      );

  final String id;
  final String eventToken;
  final Map<String, String> parameters;

  Map<String, Object> toJson() => {
    'id': id,
    'eventToken': eventToken,
    'parameters': parameters,
  };
}

class SharedPreferencesAdjustHomeFirstViewStore
    implements AdjustHomeFirstViewStore {
  static const _storageKey = 'adjust.home_first_view.reported.v1';

  @override
  Future<bool> markReportedIfNeeded() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_storageKey) == true) return false;
    await preferences.setBool(_storageKey, true);
    return true;
  }
}

/// 独立于内部埋点的 Adjust 客户端事件上报器。
///
/// 调用方不得 await [reportDramaPlayStart] 与 [reportCheckoutStart]；首次首页
/// 事件由调用方以 unawaited 方式触发。所有异常都在此处吞掉，不能影响 UI、支付
/// 或内部埋点链路。
class AdjustEventReporter {
  AdjustEventReporter({
    AdjustEventClient? eventClient,
    AdjustHomeFirstViewStore? homeFirstViewStore,
  }) : _eventClient = eventClient ?? AdjustSdkEventClient(),
       _homeFirstViewStore =
           homeFirstViewStore ?? SharedPreferencesAdjustHomeFirstViewStore();

  final AdjustEventClient _eventClient;
  final AdjustHomeFirstViewStore _homeFirstViewStore;

  void reportAppFirstOpen() => _report(AdjustEventTokens.appFirstOpen);

  void reportDramaPlayStart() => _report(AdjustEventTokens.dramaPlayStart);

  Future<void> recoverPendingEvents() => _eventClient.recoverPendingEvents();

  Future<void> reportHomeFirstView() async {
    try {
      if (!await _homeFirstViewStore.markReportedIfNeeded()) return;
      _eventClient.track(AdjustEventTokens.homeFirstView);
    } catch (error, stackTrace) {
      _logFailure(AdjustEventTokens.homeFirstView, error, stackTrace);
    }
  }

  void reportCheckoutStart({
    required String productType,
    required String productId,
    required num price,
    required String currency,
  }) {
    _report(
      AdjustEventTokens.checkoutStart,
      parameters: {
        'product_type': productType,
        'product_id': productId,
        'price': price.toString(),
        'currency': currency,
      },
    );
  }

  void _report(String eventToken, {Map<String, String> parameters = const {}}) {
    unawaited(
      Future<void>(() {
        try {
          _eventClient.track(eventToken, parameters: parameters);
        } catch (error, stackTrace) {
          _logFailure(eventToken, error, stackTrace);
        }
      }),
    );
  }

  void _logFailure(String eventToken, Object error, StackTrace stackTrace) {
    debugPrint('[Adjust] Event $eventToken skipped: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
