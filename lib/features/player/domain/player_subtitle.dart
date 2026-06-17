/// 播放器字幕领域模型。
///
/// 描述一个可用的字幕轨道，包含远程字幕文件 URL 和元数据。
/// 真实字幕内容需要异步下载并解析为 [SubtitleCue] 列表。
class PlayerSubtitle {
  const PlayerSubtitle({
    required this.id,
    required this.language,
    required this.name,
    required this.url,
    required this.format,
    required this.isDefault,
  });

  /// 字幕 id，用于切换和持久化用户选择。
  final int id;

  /// 字幕语言标签（如 "en"、"zh"、"es"）。
  final String language;

  /// 字幕显示名称（如 "English"、"简体中文"）。
  final String name;

  /// 远程字幕文件 URL（VTT 或 SRT 格式）。
  final String url;

  /// 字幕文件格式（"vtt" 或 "srt"）。
  final String format;

  /// 是否为默认字幕轨道。
  final bool isDefault;

  @override
  bool operator ==(Object other) {
    return other is PlayerSubtitle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 单条字幕条目。
///
/// 解析后的字幕文件会转成此模型列表，播放器根据当前位置选择要渲染的条目。
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  /// 字幕开始时间。
  final Duration start;

  /// 字幕结束时间。
  final Duration end;

  /// 字幕文本内容（可能包含换行）。
  final String text;

  /// 当前播放位置是否在此字幕时间范围内。
  bool contains(Duration position) {
    return position >= start && position <= end;
  }
}
