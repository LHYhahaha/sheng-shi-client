import 'player_feed.dart';
import 'player_video_quality.dart';

/// The source decision shared between startup preheat and the player entry.
///
/// Keeping this decision in one object prevents Home from warming one HLS
/// rendition while the player resolves and opens another one on tap.
class PlayerStartupQualityPlan {
  const PlayerStartupQualityPlan({
    required this.itemId,
    required this.masterSourceUrl,
    required this.playableSourceUrl,
    required this.preferenceId,
    required this.effectiveQualityId,
    required this.qualities,
  });

  final String itemId;
  final String masterSourceUrl;
  final String playableSourceUrl;
  final String preferenceId;
  final String effectiveQualityId;
  final List<PlayerVideoQuality> qualities;

  bool matches(PlayerFeedItem item) =>
      item.id == itemId && item.episode.videoSource == masterSourceUrl;

  PlayerFeedItem applyTo(PlayerFeedItem item) => item.copyWith(
    episode: item.episode.copyWith(videoUrl: playableSourceUrl),
  );
}
