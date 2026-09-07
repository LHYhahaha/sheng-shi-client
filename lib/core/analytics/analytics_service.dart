import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

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

/// 自研埋点批量上传 Sink。
///
/// 事件会先持久化到本地，再按「最多 20 条或 5 秒」发送；失败事件保留原始
/// payload，因此重试时不会改变 event_id 和 event_time。
class AnalyticsBatchUploadEventSink implements AnalyticsEventSink {
  AnalyticsBatchUploadEventSink({
    required ApiClient Function() apiClientReader,
    this.batchSize = 20,
    this.flushDelay = const Duration(seconds: 5),
    bool uploadsEnabled = true,
  }) : assert(batchSize > 0),
       _apiClientReader = apiClientReader,
       _uploadsEnabled = uploadsEnabled;

  /// 上传可能在语言切换、测试网络切换之后才由重试计时器触发，因此不能
  /// 固定创建时的 ApiClient；发送前读取当前实例以带上最新请求上下文。
  final ApiClient Function() _apiClientReader;
  final int batchSize;
  final Duration flushDelay;
  final List<AnalyticsPayload> _pending = <AnalyticsPayload>[];
  Future<void>? _uploading;
  Future<void>? _initializing;
  Timer? _flushTimer;
  bool _uploadsEnabled;

  static const _pendingStorageKey = 'analytics.pending_events.v1';

  static const _trackSignSecret =
      '17dce3b10ae0a0b0a337fa266b11cd0ac6f2f3f8847f08cb7a3cdb9783aba3ac';

  /// 恢复上次未成功发送的事件。
  ///
  /// App 启动阶段可先恢复队列、等待用户公共参数就绪，再通过
  /// [enableUploads] 开始发送，避免首批请求缺少 userId。
  Future<void> initialize() {
    return _initializing ??= _restorePending();
  }

  /// 开启上传并立即发送已恢复或已入队的事件。
  Future<void> enableUploads() async {
    _uploadsEnabled = true;
    await initialize();
    await _flushPending();
  }

  @override
  Future<void> enqueue(AnalyticsPayload payload) async {
    await initialize();
    // 埋点接入批量上传后，事件会先在本地队列等待聚合；开发阶段仍须在“业务
    // 发生时”立即打印，不能等到 5 秒后从网络请求日志间接确认，否则 page_view
    // 和 page_leave 等事件会看起来像没有触发。
    if (kDebugMode) {
      debugPrint(
        '[Analytics] ${const JsonEncoder.withIndent('  ').convert(payload.toJson())}',
      );
    }
    _pending.add(payload);
    await _persistPending();
    if (!_uploadsEnabled) {
      return;
    }
    if (_pending.length >= batchSize) {
      await _flushPending();
      return;
    }
    _scheduleFlush();
  }

  /// 供切后台、网络恢复等时机立即补发。
  Future<void> flush() async {
    await initialize();
    if (!_uploadsEnabled) return;
    await _flushPending();
  }

  void dispose() {
    _flushTimer?.cancel();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(flushDelay, () {
      unawaited(flush());
    });
  }

  Future<void> _flushPending() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_uploading != null) return _uploading!;
    _uploading = _doFlush();
    try {
      await _uploading;
    } finally {
      _uploading = null;
    }
  }

  Future<void> _doFlush() async {
    while (_pending.isNotEmpty) {
      final batch = _pending.take(batchSize).toList(growable: false);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final rawBody = jsonEncode({
        'events': batch.map(_toRequestEvent).toList(growable: false),
      });
      final bodySha256 = sha256.convert(utf8.encode(rawBody)).toString();
      final trackSign = Hmac(
        sha256,
        utf8.encode(_trackSignSecret),
      ).convert(utf8.encode('$timestamp\n$bodySha256')).toString();
      try {
        await _apiClientReader().post<Map<String, Object?>>(
          '/api/analytics/event/batch-upload',
          data: rawBody,
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {'Track-Timestamp': timestamp, 'Track-Sign': trackSign},
          ),
          decoder: (data) => Map<String, Object?>.from(data! as Map),
        );
        _pending.removeRange(0, batch.length);
        await _persistPending();
      } catch (error) {
        debugPrint('[Analytics] Batch upload failed: $error');
        _scheduleFlush();
        return;
      }
    }
  }

  Future<void> _restorePending() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedEvents = preferences.getStringList(_pendingStorageKey);
      if (storedEvents == null) return;
      for (final encoded in storedEvents) {
        final decoded = jsonDecode(encoded);
        if (decoded is Map<String, Object?>) {
          _pending.add(_payloadFromJson(decoded));
        } else if (decoded is Map) {
          _pending.add(_payloadFromJson(Map<String, Object?>.from(decoded)));
        }
      }
    } catch (error) {
      debugPrint('[Analytics] Failed to restore pending events: $error');
    }
  }

  Future<void> _persistPending() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_pending.isEmpty) {
        await preferences.remove(_pendingStorageKey);
        return;
      }
      await preferences.setStringList(
        _pendingStorageKey,
        _pending
            .map((payload) => jsonEncode(payload.toJson()))
            .toList(growable: false),
      );
    } catch (error) {
      debugPrint('[Analytics] Failed to persist pending events: $error');
    }
  }

  AnalyticsPayload _payloadFromJson(Map<String, Object?> json) {
    final common = Map<String, Object?>.from(json['common_params']! as Map);
    final eventParams = Map<String, Object?>.from(json['event_params']! as Map);
    return AnalyticsPayload(
      eventName: json['event_name']! as String,
      commonParams: AnalyticsCommonParams(
        eventId: common['event_id']! as String,
        eventTime: common['event_time']! as int,
        context: AnalyticsContext(
          platform: common['platform']! as String,
          appVersion: common['app_version']! as String,
          language: common['language']! as String,
          deviceId: common['device_id'] as String?,
          userId: common['user_id'] as String?,
          channelId: common['channel_id'] as String?,
          merchantId: common['merchant_id'] as String?,
          regionCode: common['region_code'] as String?,
          pageName: common['page_name'] as String?,
          previousPage: common['previous_page'] as String?,
          entrySourceType: common['entry_source_type'] as String?,
          entrySourceId: common['entry_source_id'] as String?,
          h5VisitorId: common['h5_visitor_id'] as String?,
        ),
      ),
      eventParams: eventParams,
    );
  }

  Map<String, Object?> _toRequestEvent(AnalyticsPayload payload) {
    final common = payload.commonParams.toJson();
    return {
      'eventName': payload.eventName,
      'commonParams': {
        'appVersion': common['app_version'],
        'channelId': common['channel_id'],
        'deviceId': common['device_id'],
        'entrySourceId': common['entry_source_id'],
        'entrySourceType': common['entry_source_type'],
        'eventId': common['event_id'],
        'eventTime': common['event_time'],
        'h5VisitorId': common['h5_visitor_id'],
        'language': common['language'],
        'merchantId': common['merchant_id'],
        'pageName': common['page_name'],
        'platform': common['platform'],
        'previousPage': common['previous_page'],
        'regionCode': common['region_code'],
        'userId': common['user_id'],
      },
      'eventParams': payload.eventParams.isEmpty
          ? ''
          : jsonEncode(payload.eventParams),
    };
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
  Future<AnalyticsPayload?> track(
    AnalyticsEvent event, {

    /// 事件真实发生时间。用于页面首帧等需要等待公共上下文就绪后才写入队列的场景。
    /// 未传时使用当前时间。
    DateTime? occurredAt,

    /// 事件发生时已捕获的公共上下文。
    ///
    /// 用于登出成功后账户资料已清理、但事件仍须归属到退出前用户的场景。
    AnalyticsContext? context,
  }) async {
    try {
      _validator.validate(event);
    } on AnalyticsValidationError catch (error) {
      _onValidationError?.call(error);
      return null;
    }

    final now = (occurredAt ?? _clock()).toUtc();
    final commonParams = AnalyticsCommonParams(
      eventId: _eventIdGenerator(),
      eventTime: now.millisecondsSinceEpoch,
      context: context ?? _contextReader(),
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
