import 'player_episode_dto.dart';

/// 播放器剧详情远程 DTO。
class PlayerContentDto {
  const PlayerContentDto({
    required this.dramaId,
    required this.title,
    required this.description,
    required this.posterUrl,
    required this.backgroundUrl,
    required this.totalEpisodes,
    required this.tags,
    required this.viewCount,
    required this.viewCountLabel,
    required this.likeCountLabel,
    required this.episodes,
  });

  final String dramaId;
  final String title;
  final String? description;
  final String? posterUrl;
  final String? backgroundUrl;
  final int totalEpisodes;
  final List<String> tags;
  final int? viewCount;
  final String? viewCountLabel;
  final String? likeCountLabel;
  final List<PlayerEpisodeDto> episodes;

  factory PlayerContentDto.fromJson(Map<String, Object?> json) {
    final rawEpisodes = json['episodes'];
    return PlayerContentDto(
      dramaId: _stringValue(json['dramaId']) ?? _stringValue(json['id']) ?? '',
      title: _stringValue(json['title']) ?? '',
      description: _stringValue(json['description']),
      posterUrl: _stringValue(json['posterUrl']),
      backgroundUrl: _stringValue(json['backgroundUrl']),
      totalEpisodes: _intValue(json['totalEpisodes']) ?? 0,
      tags: _stringList(json['tags']),
      viewCount: _intValue(json['viewCount']),
      viewCountLabel: _stringValue(json['viewCountLabel']),
      likeCountLabel: _stringValue(json['likeCountLabel']),
      episodes: rawEpisodes is List
          ? rawEpisodes
                .whereType<Map<String, Object?>>()
                .map(PlayerEpisodeDto.fromJson)
                .toList(growable: false)
          : const <PlayerEpisodeDto>[],
    );
  }

  static String? _stringValue(Object? value) => value is String ? value : null;

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
