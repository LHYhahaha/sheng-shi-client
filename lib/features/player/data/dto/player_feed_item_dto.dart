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
    final resolvedDramaJson = dramaJson is Map
        ? Map<String, Object?>.from(dramaJson)
        : json;
    final resolvedEpisodeJson = episodeJson is Map
        ? Map<String, Object?>.from(episodeJson)
        : _resolveEpisodeJson(json);
    final drama = PlayerContentDto.fromJson(resolvedDramaJson);
    final episode = PlayerEpisodeDto.fromJson(resolvedEpisodeJson);
    final dramaId =
        _stringValue(json['dramaId']) ??
        _stringValue(json['id']) ??
        drama.id.toString();
    final episodeId =
        _stringValue(json['episodeId']) ??
        _positiveIdString(json['episode_id']) ??
        episode.id.toString();

    return PlayerFeedItemDto(
      feedItemId: _stringValue(json['feedItemId']) ?? '',
      dramaId: dramaId,
      episodeId: episodeId,
      reason: _stringValue(json['reason']),
      rankingScore: _doubleValue(json['rankingScore']),
      drama: drama,
      episode: episode,
    );
  }

  static Map<String, Object?> _resolveEpisodeJson(Map<String, Object?> json) {
    final episodes = json['episodes'];
    if (episodes is! List || episodes.isEmpty) {
      return json;
    }

    final episodeMaps = episodes
        .whereType<Map>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);
    if (episodeMaps.isEmpty) {
      return json;
    }

    final episodeId = _intValue(json['episode_id']);
    final episodeNo = _intValue(json['episode_no']);
    for (final episode in episodeMaps) {
      if ((episodeId != null && _intValue(episode['id']) == episodeId) ||
          (episodeNo != null &&
              _intValue(episode['episode_no']) == episodeNo)) {
        return episode;
      }
    }

    return episodeMaps.first;
  }

  static String? _stringValue(Object? value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    return null;
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _positiveIdString(Object? value) {
    final id = _intValue(value);
    return id != null && id > 0 ? id.toString() : null;
  }

  static double? _doubleValue(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
