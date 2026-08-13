import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PlayerFrameJankDiagnostics {
  PlayerFrameJankDiagnostics({
    required this.sessionKey,
    this.slowFrameThreshold = const Duration(milliseconds: 16),
    this.severeFrameThreshold = const Duration(milliseconds: 32),
  });

  static const enabled = bool.fromEnvironment('PLAYER_TIMING_LOGS');

  final String sessionKey;
  final Duration slowFrameThreshold;
  final Duration severeFrameThreshold;

  String _phase = 'idle';
  String? _itemId;
  int _frames = 0;
  int _slowFrames = 0;
  int _severeFrames = 0;
  Duration _maxBuildDuration = Duration.zero;
  Duration _maxRasterDuration = Duration.zero;
  TimingsCallback? _timingsCallback;

  void start() {
    if (!enabled || _timingsCallback != null) {
      return;
    }
    _timingsCallback = (timings) {
      for (final timing in timings) {
        recordFrameDurations(
          buildDuration: timing.buildDuration,
          rasterDuration: timing.rasterDuration,
        );
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
    debugPrint('[player-jank] start session=$sessionKey');
  }

  void stop() {
    final callback = _timingsCallback;
    if (callback == null) {
      return;
    }
    SchedulerBinding.instance.removeTimingsCallback(callback);
    _timingsCallback = null;
    _logSummary('stop');
  }

  void markPhase(String phase, {String? itemId}) {
    if (_frames > 0) {
      _logSummary('phase_end');
    }
    _phase = phase;
    _itemId = itemId;
    _resetCounters();
    if (enabled) {
      debugPrint(
        '[player-jank] phase_start session=$sessionKey phase=$_phase '
        'item=${_itemId ?? 'null'}',
      );
    }
  }

  void recordFrameDurations({
    required Duration buildDuration,
    required Duration rasterDuration,
  }) {
    _frames += 1;
    if (buildDuration > _maxBuildDuration) {
      _maxBuildDuration = buildDuration;
    }
    if (rasterDuration > _maxRasterDuration) {
      _maxRasterDuration = rasterDuration;
    }
    final frameDuration = buildDuration > rasterDuration
        ? buildDuration
        : rasterDuration;
    if (frameDuration > slowFrameThreshold) {
      _slowFrames += 1;
    }
    if (frameDuration > severeFrameThreshold) {
      _severeFrames += 1;
    }
    if (enabled && frameDuration > severeFrameThreshold) {
      debugPrint(
        '[player-jank] severe_frame ${_summaryParts().join(' ')} '
        'buildMs=${buildDuration.inMilliseconds} '
        'rasterMs=${rasterDuration.inMilliseconds}',
      );
    }
  }

  String exportSummary() {
    return '[player-jank] summary ${_summaryParts().join(' ')}';
  }

  void _logSummary(String event) {
    if (!enabled) {
      return;
    }
    debugPrint('[player-jank] $event ${_summaryParts().join(' ')}');
  }

  List<String> _summaryParts() {
    return [
      'session=$sessionKey',
      'phase=$_phase',
      'item=${_itemId ?? 'null'}',
      'frames=$_frames',
      'slowFrames=$_slowFrames',
      'severeFrames=$_severeFrames',
      'maxBuildMs=${_maxBuildDuration.inMilliseconds}',
      'maxRasterMs=${_maxRasterDuration.inMilliseconds}',
    ];
  }

  void _resetCounters() {
    _frames = 0;
    _slowFrames = 0;
    _severeFrames = 0;
    _maxBuildDuration = Duration.zero;
    _maxRasterDuration = Duration.zero;
  }
}
