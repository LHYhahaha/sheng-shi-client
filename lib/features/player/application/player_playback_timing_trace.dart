import 'package:flutter/foundation.dart';

/// 播放链路 timing 事件。
///
/// 事件同时记录 trace 起点、用户动作起点和 source label，用来定位“点击/滑动到首帧”
/// 的耗时。不要在 report 里默认暴露完整 source URL 给普通 UI，签名 URL 后续可能
/// 带鉴权参数。
class PlayerPlaybackTimingEvent {
  const PlayerPlaybackTimingEvent({
    required this.name,
    required this.at,
    this.traceId,
    this.itemId,
    this.source,
    this.sourceLabel,
    this.elapsed,
    this.sinceTraceStart,
    this.sinceUserAction,
    this.error,
    this.details,
  });

  /// 事件名称。
  ///
  /// 名称保持短字符串，方便在测试和日志里搜索。不要把动态数据拼进名称，动态数据放
  /// `details`。
  final String name;

  /// 事件发生时间。
  ///
  /// 用本地时间只用于诊断排序，不作为服务端埋点可信时间。
  final DateTime at;

  /// 当前播放 trace id。
  ///
  /// 同一次 playItem/open 链路共享一个 trace，便于串起用户动作、source resolve、
  /// media open 和 first frame。
  final String? traceId;

  /// 事件关联的 item id。
  ///
  /// 可为空，因为某些事件是 session 生命周期或全局释放事件，不绑定具体 item。
  final String? itemId;

  /// 事件关联的 source。
  ///
  /// 可能包含签名 URL 或 local proxy URL；导出给普通 UI 时应谨慎，避免泄漏鉴权参数。
  final String? source;

  /// source 的可读分类标签。
  ///
  /// 用于报告里快速区分远端 fixture、local proxy 等来源，不替代真实 URL。
  final String? sourceLabel;

  /// 单个操作自己的耗时。
  ///
  /// 例如 source resolve 或 media open 的耗时；不等同于从用户点击到首帧的总耗时。
  final Duration? elapsed;

  /// 距离当前 trace start 的时间。
  ///
  /// 用于定位播放链路内部哪个阶段慢。
  final Duration? sinceTraceStart;

  /// 距离用户动作发生的时间。
  ///
  /// 用于衡量点击/滑动到关键事件的感知耗时；如果没有显式用户动作，则从 trace start
  /// 近似计算。
  final Duration? sinceUserAction;

  /// 事件附带错误。
  ///
  /// 仅用于诊断，不直接面向用户展示。
  final Object? error;

  /// 事件附加细节。
  ///
  /// 放置 key=value 形式的诊断信息。不要在事件名称中塞这些动态字段。
  final String? details;
}

/// 播放器 timing trace 收集器。
///
/// trace 不是业务状态，不参与播放决策；它只帮助排查 source resolve、media open、
/// first frame、prepared hit/miss 等链路。事件数量有上限，避免长时间滑动导致内存增长。
class PlayerPlaybackTimingTrace {
  PlayerPlaybackTimingTrace({required this.sessionKey});

  final String sessionKey;
  final _events = <PlayerPlaybackTimingEvent>[];
  int _traceCounter = 0;
  String? _traceId;
  DateTime? _traceStartedAt;
  DateTime? _traceUserActionAt;
  String? _pendingTrigger;
  String? _pendingFromItemId;
  String? _pendingToItemId;
  DateTime? _pendingUserActionAt;

  List<PlayerPlaybackTimingEvent> get events =>
      List<PlayerPlaybackTimingEvent>.unmodifiable(_events);

  void recordUserAction(
    String event, {
    String? trigger,
    String? fromItemId,
    String? toItemId,
    String? direction,
    int? fromIndex,
    int? toIndex,
    DateTime? occurredAt,
  }) {
    // 用户动作先作为 pending 记录，下一次 trace start 会把它绑定到播放请求。
    // 这样 route push、PageView 滑动和自动下一集都能统一计算 sinceUserAction。
    _pendingTrigger = trigger ?? event;
    _pendingFromItemId = fromItemId;
    _pendingToItemId = toItemId;
    _pendingUserActionAt = occurredAt ?? DateTime.now();
    record(
      event,
      itemId: toItemId,
      details: details([
        'trigger=${trigger ?? event}',
        'fromItemId=${fromItemId ?? 'null'}',
        'toItemId=${toItemId ?? 'null'}',
        if (direction != null) 'direction=$direction',
        if (fromIndex != null) 'fromIndex=$fromIndex',
        if (toIndex != null) 'toIndex=$toIndex',
      ]),
    );
  }

  void start({
    required String? itemId,
    required String? source,
    required String? currentItemId,
    required String currentStatusName,
    required int generation,
  }) {
    final now = DateTime.now();
    final trigger =
        _pendingTrigger ??
        _inferTrigger(
          itemId: itemId,
          currentItemId: currentItemId,
          currentStatusName: currentStatusName,
        );
    final fromItemId = _pendingFromItemId ?? currentItemId;
    final toItemId = itemId ?? _pendingToItemId;
    _traceCounter += 1;
    _traceId =
        '${sessionKey.replaceAll(':', '-')}-${_traceCounter.toString().padLeft(3, '0')}';
    _traceStartedAt = now;
    _traceUserActionAt = _pendingUserActionAt ?? now;
    _pendingTrigger = null;
    _pendingFromItemId = null;
    _pendingToItemId = null;
    _pendingUserActionAt = null;
    record(
      'trace start',
      itemId: itemId,
      source: source,
      details: details([
        'trigger=$trigger',
        'fromItemId=${fromItemId ?? 'null'}',
        'toItemId=${toItemId ?? 'null'}',
        'generation=$generation',
      ]),
    );
  }

  void record(
    String event, {
    String? itemId,
    String? source,
    Duration? elapsed,
    Object? error,
    String? details,
  }) {
    final now = DateTime.now();
    final eventEntry = PlayerPlaybackTimingEvent(
      name: event,
      at: now,
      traceId: _traceId,
      itemId: itemId,
      source: source,
      sourceLabel: sourceLabel(source),
      elapsed: elapsed,
      sinceTraceStart: _traceStartedAt == null
          ? null
          : now.difference(_traceStartedAt!),
      sinceUserAction: _traceUserActionAt == null
          ? null
          : now.difference(_traceUserActionAt!),
      error: error,
      details: details,
    );
    _events.add(eventEntry);
    if (_events.length > 160) {
      // timing 只保留最近窗口，避免播放器长会话把诊断事件变成无限日志缓存。
      _events.removeRange(0, _events.length - 160);
    }
    const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
    if (!shouldPrint) {
      return;
    }
    debugPrint(format(eventEntry, includeSourceUrl: true));
  }

  String exportReport() {
    return _events.map(format).join('\n');
  }

  String format(
    PlayerPlaybackTimingEvent event, {
    bool includeSourceUrl = true,
  }) {
    final parts = <String>[
      event.at.toIso8601String(),
      'session=$sessionKey',
      if (event.traceId != null) 'trace=${event.traceId}',
      event.name,
      if (event.itemId != null) 'item=${event.itemId}',
      if (event.sourceLabel != null) 'sourceLabel=${event.sourceLabel}',
      if (includeSourceUrl && event.source != null) 'source=${event.source}',
      if (event.elapsed != null) 'elapsed=${event.elapsed!.inMilliseconds}ms',
      if (event.sinceTraceStart != null)
        'sinceTraceStartMs=${event.sinceTraceStart!.inMilliseconds}',
      if (event.sinceUserAction != null)
        'sinceUserActionMs=${event.sinceUserAction!.inMilliseconds}',
      if (event.details != null) event.details!,
      if (event.error != null) 'error=${event.error}',
    ];
    return parts.join(' ');
  }

  String details(List<String> parts) {
    return parts.where((part) => part.isNotEmpty).join(' ');
  }

  String _inferTrigger({
    required String? itemId,
    required String? currentItemId,
    required String currentStatusName,
  }) {
    if (itemId == null) {
      return 'clear';
    }
    if (currentStatusName == 'error') {
      return 'retry';
    }
    if (currentItemId == null) {
      return 'list_entry';
    }
    return 'programmatic';
  }

  static String sourceLabel(String? source) {
    if (source == null) {
      return 'none';
    }
    if (source.contains('127.0.0.1') || source.contains('localhost')) {
      return 'local-hls-proxy';
    }
    if (source.contains('x36xhzz')) {
      return 'mux-fast';
    }
    if (source.contains('tos_ismc')) {
      return 'mux-tears-stable';
    }
    if (source.contains('bipbop_16x9/gear1/prog_index')) {
      return 'apple-bipbop-low-stable';
    }
    if (source.contains('img_bipbop_adv_example_ts')) {
      return 'apple-bipbop-advanced-ts-test';
    }
    if (source.contains('bipbop_16x9/gear2/prog_index')) {
      return 'apple-bipbop-16x9-gear2-test';
    }
    if (source.contains('bipbop_16x9/gear3/prog_index')) {
      return 'apple-bipbop-16x9-gear3-test';
    }
    if (source.contains('bipbop_16x9/gear4/prog_index')) {
      return 'apple-bipbop-16x9-gear4-test';
    }
    if (source.contains('bipbop_16x9')) {
      return 'aspect-ratio-16x9-test';
    }
    if (source.contains('bipbop_4x3/gear1/prog_index')) {
      return 'apple-bipbop-4x3-gear1-test';
    }
    if (source.contains('bipbop_4x3/gear2/prog_index')) {
      return 'apple-bipbop-4x3-gear2-test';
    }
    if (source.contains('bipbop_4x3/gear3/prog_index')) {
      return 'apple-bipbop-4x3-gear3-test';
    }
    if (source.contains('bipbop_4x3/gear4/prog_index')) {
      return 'apple-bipbop-4x3-gear4-test';
    }
    if (source.contains('bipbop_4x3')) {
      return 'aspect-ratio-4x3-test';
    }
    if (source.contains('angel-one-hls')) {
      return 'shaka-angel-one-test';
    }
    if (source.contains('bbb-dark-truths-hls')) {
      return 'shaka-bbb-dark-truths-test';
    }
    if (source.contains('cph-p2p-msl.akamaized.net')) {
      return 'akamai-live-hls-test';
    }
    if (source.contains('content.jwplatform.com') ||
        source.contains('vM7nH0Kl')) {
      return 'unstable-source-test';
    }
    if (source.contains('demo.unified-streaming.com') ||
        source.contains('tears-of-steel')) {
      return 'slow-source-test';
    }
    if (source.contains('test_001/stream')) {
      return 'mux-arte-china-test';
    }
    if (source.contains('pts_shift')) {
      return 'mux-pts-shift-test';
    }
    if (source.contains('dai-discontinuity-deltatre')) {
      return 'mux-ad-discontinuity-test';
    }
    if (source.contains('issue666')) {
      return 'mux-issue666-test';
    }
    if (source.contains('lz15')) {
      return 'business-lz15';
    }
    return 'unknown-hls';
  }
}
