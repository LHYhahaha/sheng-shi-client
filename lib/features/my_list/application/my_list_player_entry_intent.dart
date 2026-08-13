import '../../player/domain/initial_playback_intent.dart';
import '../../player/domain/player_playback_progress.dart';
import '../domain/my_list_item.dart';

InitialPlaybackIntent buildMyListPlayerEntryIntent({
  required MyListItem item,
  required bool isCollection,
  required DateTime userActionAt,
}) {
  final episodeId = _entryEpisodeId(item, isCollection: isCollection);
  final trigger = isCollection
      ? 'my_list_collection_item'
      : 'play_history_item';
  final targetItemId = 'single:${item.dramaId}:$episodeId';
  final resumeProgress = _resumeProgressForItem(
    item: item,
    itemId: targetItemId,
    userActionAt: userActionAt,
  );

  return InitialPlaybackIntent.singleDrama(
    dramaId: item.dramaId.toString(),
    episodeId: episodeId,
    episodeNo: _entryEpisodeNo(item, isCollection: isCollection),
    trigger: trigger,
    userActionAt: userActionAt,
    resumeProgress: resumeProgress,
  );
}

String _entryEpisodeId(MyListItem item, {required bool isCollection}) {
  if (isCollection && item.currentEpisode > 0) {
    return item.currentEpisode.toString();
  }
  // My List history does not include the next episode's entitlement/source
  // status. Keep the route on the last watched episode and let PlayerPage's
  // detail snapshot decide whether it can safely advance.
  return item.episodeId != null && item.episodeId! > 0
      ? item.episodeId.toString()
      : '1';
}

int? _entryEpisodeNo(MyListItem item, {required bool isCollection}) {
  if (isCollection && item.currentEpisode > 0) {
    return item.currentEpisode;
  }
  if (item.episodeId == null || item.episodeId! <= 0) {
    return 1;
  }
  return null;
}

PlaybackProgress? _resumeProgressForItem({
  required MyListItem item,
  required String itemId,
  required DateTime userActionAt,
}) {
  final watchSecond = item.watchSecond;
  final durationSecond = item.durationSecond;
  if (watchSecond == null || durationSecond == null) {
    return null;
  }
  final progress = PlaybackProgress(
    itemId: itemId,
    position: Duration(seconds: watchSecond),
    duration: Duration(seconds: durationSecond),
    updatedAt: userActionAt,
  );
  return progress.canResume ? progress : null;
}
