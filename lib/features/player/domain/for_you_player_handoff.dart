import 'player_content.dart';

/// For You 与标准单剧播放页之间的一次播放交接。
class ForYouPlayerHandoff {
  const ForYouPlayerHandoff({
    required this.id,
    required this.originItemId,
    required this.dramaId,
    required this.episodeId,
    required this.position,
    required this.duration,
    this.rewoundFromCompletion = false,
  });

  final String id;
  final String originItemId;
  final String dramaId;
  final String episodeId;
  final Duration position;
  final Duration duration;
  final bool rewoundFromCompletion;
}

/// 某部剧在 For You/标准播放页中看到的最新位置。
class ForYouPlaybackSnapshot {
  const ForYouPlaybackSnapshot({
    required this.originItemId,
    required this.dramaId,
    required this.episode,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final String originItemId;
  final String dramaId;
  final PlayerEpisode episode;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;
}
