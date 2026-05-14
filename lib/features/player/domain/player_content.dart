class PlayerContent {
  const PlayerContent({
    required this.id,
    required this.title,
    required this.playTitle,
    required this.synopsis,
    required this.viewCountLabel,
    required this.likeCountLabel,
    required this.backgroundAssetPath,
    required this.posterAssetPath,
    required this.episodes,
    required this.recommendations,
  });

  final String id;
  final String title;
  final String playTitle;
  final String synopsis;
  final String viewCountLabel;
  final String likeCountLabel;
  final String backgroundAssetPath;
  final String posterAssetPath;
  final List<PlayerEpisode> episodes;
  final List<PlayerRecommendation> recommendations;
}

class PlayerEpisode {
  const PlayerEpisode({
    required this.id,
    required this.number,
    required this.isLocked,
    this.videoAssetPath,
    this.videoUrl,
    this.isAvailable = true,
  });

  final String id;
  final int number;
  final bool isLocked;
  final String? videoAssetPath;
  final String? videoUrl;
  final bool isAvailable;

  bool get isUnavailable => !isAvailable;

  String? get videoSource {
    if (videoUrl != null && videoUrl!.isNotEmpty) {
      return videoUrl;
    }
    if (videoAssetPath != null && videoAssetPath!.isNotEmpty) {
      return 'asset:///$videoAssetPath';
    }
    return null;
  }
}

class PlayerRecommendation {
  const PlayerRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverAssetPath,
  });

  final String id;
  final String title;
  final String subtitle;
  final String coverAssetPath;
}

abstract interface class PlayerContentRepository {
  Future<PlayerContent> getPlayerContent({required String dramaId});
}
