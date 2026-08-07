import 'dart:async';

import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_event.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'adjust_service.dart';

/// 客户端可上报的 Adjust 事件 token。
abstract final class AdjustEventTokens {
  static const dramaPlayStart = 'x7p5qa';
  static const homeFirstView = '37fm6a';
  static const checkoutStart = 'm8l7ax';
}

/// 隔离 Adjust SDK，便于事件规则独立测试。
abstract interface class AdjustEventClient {
  void track(String eventToken, {Map<String, String> parameters = const {}});
}

class AdjustSdkEventClient implements AdjustEventClient {
  AdjustSdkEventClient({AdjustService? service})
    : _service = service ?? AdjustService();

  final AdjustService _service;

  @override
  void track(String eventToken, {Map<String, String> parameters = const {}}) {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    _service.initialize();
    final event = AdjustEvent(eventToken);
    // 4.1 明确要求 checkout_start 携带商品参数。
    parameters.forEach(event.addCallbackParameter);
    Adjust.trackEvent(event);
  }
}

abstract interface class AdjustHomeFirstViewStore {
  Future<bool> markReportedIfNeeded();
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

  void reportDramaPlayStart() => _report(AdjustEventTokens.dramaPlayStart);

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
