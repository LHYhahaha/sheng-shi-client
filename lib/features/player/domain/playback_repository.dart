import 'playback_media.dart';

abstract interface class PlaybackRepository {
  Future<PlaybackMedia> getPlaybackMedia({
    required String dramaId,
    required String episodeId,
  });
}
