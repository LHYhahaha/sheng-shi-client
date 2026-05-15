/// 播放源字幕轨道 DTO。
class SubtitleTrackDto {
  const SubtitleTrackDto({
    required this.language,
    required this.label,
    required this.url,
    required this.format,
    required this.isDefault,
  });

  final String language;
  final String label;
  final String url;
  final String format;
  final bool isDefault;

  factory SubtitleTrackDto.fromJson(Map<String, Object?> json) {
    return SubtitleTrackDto(
      language: json['language'] is String ? json['language']! as String : '',
      label: json['label'] is String ? json['label']! as String : '',
      url: json['url'] is String ? json['url']! as String : '',
      format: json['format'] is String ? json['format']! as String : 'vtt',
      isDefault: json['isDefault'] == true,
    );
  }
}
