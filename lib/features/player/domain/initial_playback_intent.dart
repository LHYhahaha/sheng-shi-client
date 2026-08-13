import 'player_playback_progress.dart';

/// Player route entry intent that cannot safely live in query parameters.
///
/// Keep URL path/query as the navigable address. This object carries local
/// in-memory hints, such as already-known watch progress from a list row.
class InitialPlaybackIntent {
  const InitialPlaybackIntent({
    required this.dramaId,
    required this.episodeId,
    required this.trigger,
    required this.userActionAt,
    this.episodeNo,
    this.resumeProgress,
  });

  factory InitialPlaybackIntent.singleDrama({
    required String dramaId,
    required String episodeId,
    int? episodeNo,
    required String trigger,
    required DateTime userActionAt,
    PlaybackProgress? resumeProgress,
  }) {
    return InitialPlaybackIntent(
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: episodeNo,
      trigger: trigger,
      userActionAt: userActionAt,
      resumeProgress: resumeProgress,
    );
  }

  final String dramaId;
  final String episodeId;
  final int? episodeNo;
  final String trigger;
  final DateTime userActionAt;
  final PlaybackProgress? resumeProgress;

  String get targetItemId => 'single:$dramaId:$episodeId';
}
