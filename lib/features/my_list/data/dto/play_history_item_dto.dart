import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';

/// 播放历史远程 DTO。
class PlayHistoryItemDto {
  const PlayHistoryItemDto({
    required this.historyId,
    required this.dramaId,
    required this.episodeId,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.coverAspectRatio,
    required this.episodeNumber,
    required this.totalEpisodes,
    required this.progressMs,
    required this.durationMs,
    required this.progressPercent,
    required this.updatedAt,
  });

  final String? historyId;
  final String dramaId;
  final String episodeId;
  final String? title;
  final String? description;
  final String? coverUrl;
  final double? coverAspectRatio;
  final int episodeNumber;
  final int totalEpisodes;
  final int? progressMs;
  final int? durationMs;
  final double? progressPercent;
  final DateTime? updatedAt;

  factory PlayHistoryItemDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'PlayHistoryItemDto';
    final historyId = JsonFieldParser.optionalString(json, 'historyId');
    final dramaId = JsonFieldParser.optionalString(json, 'dramaId');
    final episodeId = JsonFieldParser.optionalString(json, 'episodeId');
    if (dramaId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'dramaId',
        reason: 'required drama id',
      );
    }
    if (historyId == null && (episodeId == null || episodeId.isEmpty)) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'historyId',
        reason: 'historyId or episodeId required',
      );
    }

    return PlayHistoryItemDto(
      historyId: historyId,
      dramaId: dramaId,
      episodeId: episodeId ?? '',
      title: JsonFieldParser.optionalString(json, 'title'),
      description:
          JsonFieldParser.optionalString(json, 'description') ??
          JsonFieldParser.optionalString(json, 'introduction'),
      coverUrl: JsonFieldParser.optionalString(json, 'coverUrl'),
      coverAspectRatio: _doubleValue(json['coverAspectRatio']),
      episodeNumber: JsonFieldParser.optionalInt(json, 'episodeNumber') ?? 0,
      totalEpisodes: JsonFieldParser.optionalInt(json, 'totalEpisodes') ?? 0,
      progressMs: JsonFieldParser.optionalInt(json, 'progressMs'),
      durationMs: JsonFieldParser.optionalInt(json, 'durationMs'),
      progressPercent: _doubleValue(json['progressPercent']),
      updatedAt: JsonFieldParser.optionalDateTime(json, 'updatedAt'),
    );
  }
}

double? _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
