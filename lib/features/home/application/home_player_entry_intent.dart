import '../../player/domain/initial_playback_intent.dart';
import '../../player/domain/player_playback_progress.dart';
import '../../drama/domain/drama.dart';

InitialPlaybackIntent buildHomePlayerEntryIntent({
  required Drama drama,
  required DateTime userActionAt,
}) {
  final progress = drama.watchProgress;
  final canResume = progress?.canResume == true;
  final episodeId = canResume ? progress!.episodeId : '1';
  final episodeNo = canResume ? progress!.episodeNo : 1;
  final itemId = 'single:${drama.id}:$episodeId';
  final resumeProgress = canResume
      ? PlaybackProgress(
          itemId: itemId,
          position: Duration(seconds: progress!.positionSeconds),
          duration: Duration(seconds: progress.durationSeconds),
          updatedAt: userActionAt,
        )
      : null;

  return InitialPlaybackIntent.singleDrama(
    dramaId: drama.id,
    episodeId: episodeId,
    episodeNo: episodeNo,
    trigger: 'home_card_tap',
    userActionAt: userActionAt,
    resumeProgress: resumeProgress,
  );
}
