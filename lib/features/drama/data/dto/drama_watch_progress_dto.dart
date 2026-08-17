import 'package:drama_client/core/network/json_field_parser.dart';
import 'package:drama_client/features/drama/domain/drama_watch_progress.dart';

/// 列表接口复用的观看进度 DTO。
class DramaWatchProgressDto {
  const DramaWatchProgressDto({
    required this.episodeId,
    required this.episodeNo,
    required this.positionSeconds,
    required this.progressPercent,
    required this.durationSeconds,
  });

  final int episodeId;
  final int episodeNo;
  final int positionSeconds;
  final int progressPercent;
  final int durationSeconds;

  factory DramaWatchProgressDto.fromJson(Map<String, Object?> json) {
    return DramaWatchProgressDto(
      episodeId: JsonFieldParser.optionalInt(json, 'watch_episode_id') ?? 0,
      episodeNo: JsonFieldParser.optionalInt(json, 'watch_episode_no') ?? 0,
      positionSeconds: JsonFieldParser.optionalInt(json, 'watch_second') ?? 0,
      progressPercent:
          JsonFieldParser.optionalInt(json, 'progress_percent') ?? 0,
      durationSeconds:
          JsonFieldParser.optionalInt(json, 'duration_second') ?? 0,
    );
  }

  static DramaWatchProgressDto? fromJsonOrNull(Object? value) {
    if (value is! Map) return null;
    return DramaWatchProgressDto.fromJson(Map<String, Object?>.from(value));
  }

  DramaWatchProgress toDomain() => DramaWatchProgress(
    episodeId: episodeId.toString(),
    episodeNo: episodeNo,
    positionSeconds: positionSeconds,
    progressPercent: progressPercent,
    durationSeconds: durationSeconds,
  );
}
