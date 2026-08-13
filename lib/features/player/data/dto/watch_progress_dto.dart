import '../../../../core/network/api_mapping_exception.dart';
import '../../../../core/network/json_field_parser.dart';

/// 观看进度远程 DTO。
class WatchProgressDto {
  const WatchProgressDto({
    required this.dramaId,
    required this.episodeId,
    required this.episodeNo,
    required this.watchSecond,
    required this.durationSecond,
    required this.progressPercent,
    this.lastWatchAt,
  });

  final int dramaId;
  final int episodeId;
  final int episodeNo;
  final int watchSecond;
  final int durationSecond;
  final int progressPercent;
  final String? lastWatchAt;

  factory WatchProgressDto.fromJson(Map<String, Object?> json) {
    const dtoName = 'WatchProgressDto';
    final dramaId = JsonFieldParser.optionalInt(json, 'dramaId');
    final episodeId = JsonFieldParser.optionalInt(json, 'episodeId');

    if (dramaId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'dramaId',
        reason: 'required drama id',
      );
    }
    if (episodeId == null) {
      throw const ApiMappingException(
        dtoName: dtoName,
        field: 'episodeId',
        reason: 'required episode id',
      );
    }

    return WatchProgressDto(
      dramaId: dramaId,
      episodeId: episodeId,
      episodeNo: JsonFieldParser.optionalInt(json, 'episodeNo') ?? 0,
      watchSecond: JsonFieldParser.optionalInt(json, 'watchSecond') ?? 0,
      durationSecond: JsonFieldParser.optionalInt(json, 'durationSecond') ?? 0,
      progressPercent:
          JsonFieldParser.optionalInt(json, 'progressPercent') ?? 0,
      lastWatchAt: JsonFieldParser.optionalString(json, 'lastWatchAt'),
    );
  }

  /// `/api/home/detail` 使用 snake_case，并且续播对象不再重复 drama id。
  ///
  /// 无记录会以 `watch_episode_id=0` 返回，保留对象本身以便播放器明确回到第 1 集。
  static WatchProgressDto? fromDetailJsonOrNull(
    Object? value, {
    required int dramaId,
  }) {
    if (value is! Map<String, Object?>) return null;
    return WatchProgressDto(
      dramaId: dramaId,
      episodeId: JsonFieldParser.optionalInt(value, 'watch_episode_id') ?? 0,
      episodeNo: JsonFieldParser.optionalInt(value, 'watch_episode_no') ?? 1,
      watchSecond: JsonFieldParser.optionalInt(value, 'watch_second') ?? 0,
      durationSecond:
          JsonFieldParser.optionalInt(value, 'duration_second') ?? 0,
      progressPercent:
          JsonFieldParser.optionalInt(value, 'progress_percent') ?? 0,
    );
  }
}
