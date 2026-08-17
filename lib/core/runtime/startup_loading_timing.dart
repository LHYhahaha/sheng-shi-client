import 'dart:async';

import 'package:flutter/foundation.dart';

/// 记录应用启动到业务首页壳首次可见的等待时间。
class StartupLoadingTiming {
  Stopwatch? _stopwatch;
  Completer<void>? _endCompleter;

  void start() {
    _stopwatch = Stopwatch()..start();
    _endCompleter = Completer<void>();
    debugPrint('[StartupLoading] app-loading start: network config confirmed');
  }

  Duration? mark(String stage) {
    final elapsed = _stopwatch?.elapsed;
    if (elapsed != null) {
      debugPrint('[StartupLoading] $stage elapsedMs=${elapsed.inMilliseconds}');
    }
    return elapsed;
  }

  Duration? end() {
    final stopwatch = _stopwatch;
    if (stopwatch == null) {
      return null;
    }
    stopwatch.stop();
    _stopwatch = null;
    _endCompleter?.complete();
    _endCompleter = null;
    return stopwatch.elapsed;
  }

  /// 等待首页壳首帧。尚未开始启动计时时无需额外等待。
  Future<void> waitForEnd() => _endCompleter?.future ?? Future<void>.value();
}

final startupLoadingTiming = StartupLoadingTiming();
