import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';

/// 播放历史远程 DTO。
class PlayHistoryItemDto {
  const PlayHistoryItemDto({
    required this.dramaId,
    required this.episodeId,
    required this.episodeNo,
    required this.watchSecond,
    required this.durationSecond,
    required this.watchCount,
    required this.progressPercent,
    required this.lastWatchAt,
    this.historyId,
  });

  final int dramaId;
  final int episodeId;
  final int episodeNo;
  final int watchSecond;
  final int durationSecond;
  final int watchCount;
  final int progressPercent;
  final String? lastWatchAt;
  final int? historyId;

  factory PlayHistoryItemDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'PlayHistoryItemDto';
    final dramaId = JsonFieldParser.optionalInt(json, 'dramaId');
    final episodeId = JsonFieldParser.optionalInt(json, 'episodeId');

    if (dramaId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'dramaId',
        reason: 'required short id',
      );
    }
    if (episodeId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'episodeId',
        reason: 'required episode id',
      );
    }

    return PlayHistoryItemDto(
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: JsonFieldParser.optionalInt(json, 'episodeNo') ?? 0,
      watchSecond: JsonFieldParser.optionalInt(json, 'watchSecond') ?? 0,
      durationSecond: JsonFieldParser.optionalInt(json, 'durationSecond') ?? 0,
      watchCount: JsonFieldParser.optionalInt(json, 'watchCount') ?? 0,
      progressPercent:
          JsonFieldParser.optionalInt(json, 'progressPercent') ?? 0,
      lastWatchAt: JsonFieldParser.optionalString(json, 'lastWatchAt'),
      historyId: JsonFieldParser.optionalInt(json, 'historyId'),
    );
  }
}
