/// One visit to a drama in the ordinary player. The clock is monotonic wall time,
/// independent of media position, seeks and playback speed.
class PlayerAutoFavoriteTracker {
  PlayerAutoFavoriteTracker({Duration Function()? now})
    : _now = now ?? (Stopwatch()..start()).elapsedNow;

  final Duration Function() _now;
  String? _userId;
  String? _dramaId;
  String? _episodeId;
  int? _episodeNumber;
  bool _forward = false;
  bool _eligibleBeforeSwitch = false;
  bool _started = false;
  final Set<String> _episodes = {};
  Duration _elapsed = Duration.zero;
  Duration? _runningSince;

  void pause() {
    final since = _runningSince;
    if (since != null) _elapsed += _now() - since;
    _runningSince = null;
  }

  void reset() {
    _userId = null;
    _dramaId = null;
    _episodeId = null;
    _episodeNumber = null;
    _episodes.clear();
    _elapsed = Duration.zero;
    _runningSince = null;
    _forward = false;
    _eligibleBeforeSwitch = false;
    _started = false;
  }

  /// Returns true only at the first full-access playback of a forward visit.
  /// Both episode count and elapsed time must qualify before entering that visit.
  bool observe({
    required String userId,
    required String dramaId,
    required String episodeId,
    required int episodeNumber,
    required bool effectivePlaying,
  }) {
    pause();
    if (_userId != userId || _dramaId != dramaId) {
      reset();
      _userId = userId;
      _dramaId = dramaId;
    }
    if (_episodeId != episodeId) {
      _forward = _episodeNumber != null && episodeNumber > _episodeNumber!;
      _eligibleBeforeSwitch =
          _episodes.length >= 2 && _elapsed >= const Duration(seconds: 120);
      _episodeId = episodeId;
      _episodeNumber = episodeNumber;
      _started = false;
    }
    if (!effectivePlaying || userId.isEmpty) return false;
    _runningSince = _now();
    if (_started) return false;
    _started = true;
    _episodes.add(episodeId);
    return _forward && _eligibleBeforeSwitch;
  }
}

extension on Stopwatch {
  Duration elapsedNow() => elapsed;
}
