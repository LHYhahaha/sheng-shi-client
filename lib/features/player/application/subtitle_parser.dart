import 'package:flutter/foundation.dart';

import '../domain/player_subtitle.dart';

/// 字幕解析器。
///
/// 支持 WebVTT (.vtt) 和 SubRip (.srt) 格式。
/// 解析结果为 [SubtitleCue] 列表，按开始时间升序排列。
class SubtitleParser {
  SubtitleParser._();

  /// 解析字幕文件内容。
  ///
  /// [content] 为字幕文件原始文本，[format] 为 "vtt" 或 "srt"。
  /// 解析失败返回空列表，不抛异常，避免单条字幕错误阻塞播放。
  static List<SubtitleCue> parse({
    required String content,
    required String format,
  }) {
    try {
      final normalized = _normalizeLineBreaks(content);
      if (format.toLowerCase() == 'vtt') {
        return _parseVtt(normalized);
      } else if (format.toLowerCase() == 'srt') {
        return _parseSrt(normalized);
      } else {
        debugPrint('[SubtitleParser] Unsupported format: $format');
        return [];
      }
    } catch (e, st) {
      debugPrint('[SubtitleParser] Parse error: $e\n$st');
      return [];
    }
  }

  /// 规范化换行符为 \n。
  static String _normalizeLineBreaks(String content) {
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// 解析 WebVTT 格式。
  ///
  /// 规范：https://www.w3.org/TR/webvtt1/
  static List<SubtitleCue> _parseVtt(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
    var i = 0;

    // 跳过 WEBVTT 头部
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        break;
      }
      if (line.startsWith('WEBVTT')) {
        i++;
        continue;
      }
      // 跳过头部注释和 X-TIMESTAMP-MAP 等元数据
      i++;
    }

    // 解析字幕条目
    while (i < lines.length) {
      // 跳过空行
      if (lines[i].trim().isEmpty) {
        i++;
        continue;
      }

      // 跳过序号行（可选）
      final line = lines[i].trim();
      if (int.tryParse(line) != null) {
        i++;
        continue;
      }

      // 解析时间行 "00:00:01.000 --> 00:00:04.000"
      if (line.contains('-->')) {
        final times = _parseVttTimeLine(line);
        if (times == null) {
          i++;
          continue;
        }
        final start = times[0];
        final end = times[1];
        i++;

        // 收集字幕文本（可能多行）
        final textBuffer = StringBuffer();
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          if (textBuffer.isNotEmpty) {
            textBuffer.write('\n');
          }
          textBuffer.write(lines[i].trim());
          i++;
        }

        cues.add(SubtitleCue(
          start: start,
          end: end,
          text: textBuffer.toString(),
        ));
        continue;
      }

      // 跳过未知行
      i++;
    }

    return cues;
  }

  /// 解析 VTT/SRT 时间行。
  static List<Duration>? _parseVttTimeLine(String line) {
    final parts = line.split('-->');
    if (parts.length != 2) return null;
    final start = _parseTimeStamp(parts[0].trim());
    final end = _parseTimeStamp(parts[1].trim());
    if (start == null || end == null) return null;
    return [start, end];
  }

  /// 解析时间字符串为 Duration。
  ///
  /// 支持格式：
  /// - 00:00:01.000
  /// - 00:01.000
  /// - 01.000
  static Duration? _parseTimeStamp(String time) {
    try {
      // 移除可能的样式信息（如 "00:00:01.000 align:start"）
      final cleanTime = time.split(RegExp(r'\s+'))[0];
      final parts = cleanTime.split(':');
      if (parts.length == 3) {
        // HH:MM:SS.mmm 或 HH:MM:SS:mmm
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      } else if (parts.length == 2) {
        // MM:SS.mmm
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// 解析 SubRip (SRT) 格式。
  ///
  /// 规范：https://www.itu.int/itudoc/itu-t/bdt/ob/3756.doc
  static List<SubtitleCue> _parseSrt(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
    var i = 0;

    while (i < lines.length) {
      // 跳过空行
      if (lines[i].trim().isEmpty) {
        i++;
        continue;
      }

      // 序号行
      final numLine = lines[i].trim();
      if (int.tryParse(numLine) == null) {
        i++;
        continue;
      }
      i++;

      // 时间行 "00:00:01,000 --> 00:00:04,000"
      if (i >= lines.length) break;
      final timeLine = lines[i].trim();
      i++;

      final times = _parseSrtTimeLine(timeLine);
      if (times == null) continue;
      final start = times[0];
      final end = times[1];

      // 收集字幕文本
      final textBuffer = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (textBuffer.isNotEmpty) {
          textBuffer.write('\n');
        }
        textBuffer.write(lines[i].trim());
        i++;
      }

      cues.add(SubtitleCue(
        start: start,
        end: end,
        text: textBuffer.toString(),
      ));
    }

    return cues;
  }

  /// 解析 SRT 时间行（使用逗号作为毫秒分隔符）。
  static List<Duration>? _parseSrtTimeLine(String line) {
    final parts = line.split('-->');
    if (parts.length != 2) return null;
    final start = _parseSrtTimeStamp(parts[0].trim());
    final end = _parseSrtTimeStamp(parts[1].trim());
    if (start == null || end == null) return null;
    return [start, end];
  }

  static Duration? _parseSrtTimeStamp(String time) {
    try {
      final cleanTime = time.split(RegExp(r'\s+'))[0];
      final parts = cleanTime.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split(',');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
