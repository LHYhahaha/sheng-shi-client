/// 播放历史远程 DTO。
///
/// 这里预留 progressMs/durationMs/progressPercent，当前 My list UI 暂不展示精确进度，
/// 但后续继续观看和播放进度同步会依赖这些字段。
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
  final String title;
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
    return PlayHistoryItemDto(
      historyId: _stringValue(json['historyId']),
      dramaId: _stringValue(json['dramaId']) ?? '',
      episodeId: _stringValue(json['episodeId']) ?? '',
      title: _stringValue(json['title']) ?? '',
      description:
          _stringValue(json['description']) ??
          _stringValue(json['introduction']),
      coverUrl: _stringValue(json['coverUrl']),
      coverAspectRatio: _doubleValue(json['coverAspectRatio']),
      episodeNumber: _intValue(json['episodeNumber']) ?? 0,
      totalEpisodes: _intValue(json['totalEpisodes']) ?? 0,
      progressMs: _intValue(json['progressMs']),
      durationMs: _intValue(json['durationMs']),
      progressPercent: _doubleValue(json['progressPercent']),
      updatedAt: _dateTimeValue(json['updatedAt']),
    );
  }
}

String? _stringValue(Object? value) => value is String ? value : null;

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _dateTimeValue(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
