import 'dart:async';

/// Serializes automatic recovery attempts for one visible playback task.
///
/// The controller owns media sessions and decides which failures are eligible.
/// This coordinator owns only retry timing: it never opens media itself, so a
/// stale item cannot reclaim a player after the user has changed pages.
class PlayerPlaybackRecoveryCoordinator {
  PlayerPlaybackRecoveryCoordinator({List<Duration>? retryDelays})
    : _retryDelays =
          retryDelays ??
          const <Duration>[
            Duration.zero,
            Duration(seconds: 1),
            Duration(seconds: 2),
            Duration(seconds: 4),
            Duration(seconds: 6),
            Duration(seconds: 8),
          ];

  final List<Duration> _retryDelays;
  Timer? _pendingRetry;
  String? _taskKey;
  var _attempt = 0;

  bool get hasPendingRetry => _pendingRetry != null;

  /// Schedules the next recovery attempt. Returns false when this task already
  /// has an in-flight retry, preserving a single network/media open at a time.
  bool scheduleRetry({
    required String taskKey,
    required void Function(int attempt) onRetry,
  }) {
    if (_taskKey != taskKey) {
      cancel();
      _taskKey = taskKey;
      _attempt = 0;
    }
    if (_pendingRetry != null) {
      return false;
    }
    final attempt = ++_attempt;
    final delay = _delayFor(attempt);
    _pendingRetry = Timer(delay, () {
      _pendingRetry = null;
      if (_taskKey != taskKey) {
        return;
      }
      onRetry(attempt);
    });
    return true;
  }

  /// Clears recovery state after a first frame or when a new source succeeds.
  void markSucceeded({String? taskKey}) {
    if (taskKey != null && _taskKey != taskKey) {
      return;
    }
    cancel();
    _taskKey = null;
    _attempt = 0;
  }

  /// Cancels the current retry. A mismatched task key is deliberately ignored
  /// so an old page cannot cancel recovery for the visible item.
  void cancel({String? taskKey}) {
    if (taskKey != null && _taskKey != taskKey) {
      return;
    }
    _pendingRetry?.cancel();
    _pendingRetry = null;
  }

  void dispose() {
    cancel();
    _taskKey = null;
    _attempt = 0;
  }

  Duration _delayFor(int attempt) {
    final index = attempt - 1;
    if (index < _retryDelays.length) {
      return _retryDelays[index];
    }
    return _retryDelays.last;
  }
}
