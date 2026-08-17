/// Tracks client-side effective advertisement watch time.
///
/// Normal backgrounding pauses time. A material-initiated external H5 is the
/// only exception and keeps time running until the ad flow leaves that state.
class AdEffectiveWatchController {
  AdEffectiveWatchController({
    required this.requiredSeconds,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final int requiredSeconds;
  final DateTime Function() _now;

  bool _materialVisible = false;
  bool _appForeground = true;
  bool _externalH5Open = false;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;

  int get watchedSeconds {
    return watchedDuration.inSeconds;
  }

  Duration get watchedDuration {
    _flush();
    final cap = Duration(seconds: requiredSeconds);
    return _accumulated > cap ? cap : _accumulated;
  }

  bool get isComplete => watchedSeconds >= requiredSeconds;

  void setMaterialVisible(bool value) {
    _transition(() => _materialVisible = value);
  }

  void setAppForeground(bool value) {
    _transition(() => _appForeground = value);
  }

  void setExternalH5Open(bool value) {
    _transition(() => _externalH5Open = value);
  }

  void _transition(void Function() change) {
    _flush();
    change();
    _syncRunningState();
  }

  bool get _isRunning =>
      _accumulated.inSeconds < requiredSeconds &&
      ((_materialVisible && _appForeground) || _externalH5Open);

  void _flush() {
    final startedAt = _runningSince;
    if (startedAt == null) {
      _syncRunningState();
      return;
    }
    _accumulated += _now().difference(startedAt);
    final cap = Duration(seconds: requiredSeconds);
    if (_accumulated > cap) _accumulated = cap;
    _runningSince = _isRunning ? _now() : null;
  }

  void _syncRunningState() {
    if (_isRunning && _runningSince == null) {
      _runningSince = _now();
    } else if (!_isRunning) {
      _runningSince = null;
    }
  }
}
