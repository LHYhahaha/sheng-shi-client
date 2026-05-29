import 'player_content_dto.dart';
import 'player_episode_dto.dart';

/// For You feed item 远程 DTO。
class PlayerFeedItemDto {
  const PlayerFeedItemDto({
    required this.feedItemId,
    required this.dramaId,
    required this.episodeId,
    required this.reason,
    required this.rankingScore,
    required this.drama,
    required this.episode,
  });

  final String feedItemId;
  final String dramaId;
  final String episodeId;
  final String? reason;
  final double? rankingScore;
  final PlayerContentDto drama;
  final PlayerEpisodeDto episode;

  factory PlayerFeedItemDto.fromJson(Map<String, Object?> json) {
    final dramaJson = json['drama'];
    final episodeJson = json['episode'];
    return PlayerFeedItemDto(
      feedItemId: _stringValue(json['feedItemId']) ?? '',
      dramaId: _stringValue(json['dramaId']) ?? '',
      episodeId: _stringValue(json['episodeId']) ?? '',
      reason: _stringValue(json['reason']),
      rankingScore: _doubleValue(json['rankingScore']),
      drama: dramaJson is Map<String, Object?>
          ? PlayerContentDto.fromJson(dramaJson)
          : const PlayerContentDto(
              id: 0,
              coverUrl: '',
              title: '',
              summary: '',
              categoryIds: [],
              tagIds: [],
              trailerEpisodeNum: 0,
              pricePerEpisode: 0,
              isVipOnly: 0,
              status: 0,
              languageMask: '',
              subtitleLangs: '',
              episodeTotal: 0,
              onlineAt: '',
              episodes: [],
              playCount: 0,
              favoriteCount: 0,
            ),
      episode: episodeJson is Map<String, Object?>
          ? PlayerEpisodeDto.fromJson(episodeJson)
          : PlayerEpisodeDto.fromJson(json),
    );
  }

  static String? _stringValue(Object? value) => value is String ? value : null;

  static double? _doubleValue(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
