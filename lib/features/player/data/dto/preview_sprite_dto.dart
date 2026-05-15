/// seek 预览雪碧图 DTO。
class PreviewSpriteDto {
  const PreviewSpriteDto({required this.spriteUrl, required this.vttUrl});

  final String? spriteUrl;
  final String? vttUrl;

  factory PreviewSpriteDto.fromJson(Map<String, Object?> json) {
    return PreviewSpriteDto(
      spriteUrl: json['previewSpriteUrl'] is String
          ? json['previewSpriteUrl']! as String
          : null,
      vttUrl: json['previewVttUrl'] is String
          ? json['previewVttUrl']! as String
          : null,
    );
  }
}
