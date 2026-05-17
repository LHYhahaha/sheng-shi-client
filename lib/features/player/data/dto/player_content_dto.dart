import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';
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
  final String? title;
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
    const dtoName = 'PlayerContentDto';
    final rawEpisodes = json['episodes'];
    final dramaId =
        JsonFieldParser.optionalString(json, 'dramaId') ??
        JsonFieldParser.optionalString(json, 'id');
    if (dramaId == null) {
      throw ApiMappingException(
        dtoName: dtoName,
        field: 'dramaId',
        reason: 'required drama id',
      );
    }

    return PlayerContentDto(
      dramaId: dramaId,
      title: JsonFieldParser.optionalString(json, 'title'),
      description: JsonFieldParser.optionalString(json, 'description'),
      posterUrl: JsonFieldParser.optionalString(json, 'posterUrl'),
      backgroundUrl: JsonFieldParser.optionalString(json, 'backgroundUrl'),
      totalEpisodes: JsonFieldParser.optionalInt(json, 'totalEpisodes') ?? 0,
      tags: _stringList(json['tags']),
      viewCount: JsonFieldParser.optionalInt(json, 'viewCount'),
      viewCountLabel: JsonFieldParser.optionalString(json, 'viewCountLabel'),
      likeCountLabel: JsonFieldParser.optionalString(json, 'likeCountLabel'),
      episodes: rawEpisodes is List
          ? rawEpisodes
                .whereType<Map<String, Object?>>()
                .map(PlayerEpisodeDto.fromJson)
                .toList(growable: false)
          : const <PlayerEpisodeDto>[],
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
