import 'package:flutter/foundation.dart';

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

  final String name;
  final DateTime at;
  final String? traceId;
  final String? itemId;
  final String? source;
  final String? sourceLabel;
  final Duration? elapsed;
  final Duration? sinceTraceStart;
  final Duration? sinceUserAction;
  final Object? error;
  final String? details;
}

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
    if (source.contains('x36xhzz')) {
      return 'mux-fast';
    }
    if (source.contains('tos_ismc')) {
      return 'mux-tears-stable';
    }
    if (source.contains('bipbop_16x9/gear1/prog_index')) {
      return 'apple-bipbop-low-stable';
    }
    if (source.contains('bipbop_16x9')) {
      return 'aspect-ratio-16x9-test';
    }
    if (source.contains('bipbop_4x3')) {
      return 'aspect-ratio-4x3-test';
    }
    if (source.contains('content.jwplatform.com') ||
        source.contains('vM7nH0Kl')) {
      return 'unstable-source-test';
    }
    if (source.contains('demo.unified-streaming.com') ||
        source.contains('tears-of-steel')) {
      return 'slow-source-test';
    }
    if (source.contains('lz15')) {
      return 'business-lz15';
    }
    return 'unknown-hls';
  }
}
