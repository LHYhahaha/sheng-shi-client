import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'analytics_context.dart';
import 'analytics_definition.dart';
import 'analytics_event.dart';

typedef AnalyticsContextReader = AnalyticsContext Function();
typedef AnalyticsEventIdGenerator = String Function();
typedef AnalyticsClock = DateTime Function();
typedef AnalyticsValidationErrorListener =
    void Function(AnalyticsValidationError error);

/// 写入后续 Outbox 或第三方 SDK 的边界。
///
/// 上传、批量、持久化与重试将在此接口的实现中完成；业务代码只依赖
/// [AnalyticsService]，不依赖具体传输方案。
abstract interface class AnalyticsEventSink {
  Future<void> enqueue(AnalyticsPayload payload);
}

/// 后端上传尚未接入期间使用的本地事件缓冲。
///
/// 仅保存当前进程中的事件，供开发调试和客户端触发链路验证；后续可在不改业务
/// 调用点的情况下替换为 Drift Outbox + 后端上传 Sink。
class AnalyticsInMemoryEventSink implements AnalyticsEventSink {
  AnalyticsInMemoryEventSink({bool logEvents = false}) : _logEvents = logEvents;

  final List<AnalyticsPayload> _events = <AnalyticsPayload>[];
  final bool _logEvents;

  List<AnalyticsPayload> get events => List.unmodifiable(_events);

  void clear() => _events.clear();

  @override
  Future<void> enqueue(AnalyticsPayload payload) async {
    _events.add(payload);
    if (_logEvents) {
      debugPrint(
        '[Analytics] ${const JsonEncoder.withIndent('  ').convert(payload.toJson())}',
      );
    }
  }
}

/// 可直接写入上传队列的完整事件。
class AnalyticsPayload {
  const AnalyticsPayload({
    required this.eventName,
    required this.commonParams,
    required this.eventParams,
  });

  final String eventName;
  final AnalyticsCommonParams commonParams;
  final Map<String, Object?> eventParams;

  Map<String, Object?> toJson() => {
    'event_name': eventName,
    'common_params': commonParams.toJson(),
    'event_params': eventParams,
  };
}

/// 统一客户端埋点入口。
class AnalyticsService {
  AnalyticsService({
    required AnalyticsContextReader contextReader,
    required AnalyticsEventSink eventSink,
    AnalyticsEventValidator? validator,
    AnalyticsEventIdGenerator? eventIdGenerator,
    AnalyticsClock? clock,
    AnalyticsValidationErrorListener? onValidationError,
  }) : _contextReader = contextReader,
       _eventSink = eventSink,
       _validator =
           validator ?? AnalyticsEventValidator(AnalyticsDefinitions.events),
       _eventIdGenerator = eventIdGenerator ?? _newEventId,
       _clock = clock ?? DateTime.now,
       _onValidationError = onValidationError;

  final AnalyticsContextReader _contextReader;
  final AnalyticsEventSink _eventSink;
  final AnalyticsEventValidator _validator;
  final AnalyticsEventIdGenerator _eventIdGenerator;
  final AnalyticsClock _clock;
  final AnalyticsValidationErrorListener? _onValidationError;

  /// 校验并写入埋点队列。校验失败不抛出到业务调用方，也不发送事件。
  Future<AnalyticsPayload?> track(AnalyticsEvent event) async {
    try {
      _validator.validate(event);
    } on AnalyticsValidationError catch (error) {
      _onValidationError?.call(error);
      return null;
    }

    final now = _clock().toUtc();
    final commonParams = AnalyticsCommonParams(
      eventId: _eventIdGenerator(),
      eventTime: now.millisecondsSinceEpoch,
      context: _contextReader(),
    );
    final payload = AnalyticsPayload(
      eventName: event.name,
      commonParams: commonParams,
      eventParams: Map.unmodifiable(
        Map<String, Object?>.from(event.parameters),
      ),
    );

    await _eventSink.enqueue(payload);
    return payload;
  }

  static String _newEventId() {
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    return 'evt_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }
}
