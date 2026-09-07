import '../domain/player_video_quality.dart';

/// Parses the selectable variants from an HLS master playlist without fetching
/// any media playlist or segment.  Keeping this pure makes it safe to share
/// between playback, startup preloading and UI tests.
class HlsVideoQualityParser {
  const HlsVideoQualityParser._();

  static List<PlayerVideoQuality> parse(Uri masterUri, String playlistBody) {
    final lines = playlistBody
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .toList(growable: false);
    final qualities = <PlayerVideoQuality>[];
    for (var index = 0; index < lines.length; index += 1) {
      final streamInf = lines[index];
      if (!streamInf.startsWith('#EXT-X-STREAM-INF')) continue;
      final uriLine = _nextUriLine(lines, index + 1);
      if (uriLine == null) continue;
      final resolution = RegExp(
        r'RESOLUTION=(\d+)x(\d+)',
        caseSensitive: false,
      ).firstMatch(streamInf);
      final bandwidthMatch = RegExp(
        r'(?:AVERAGE-)?BANDWIDTH=(\d+)',
      ).firstMatch(streamInf);
      final height = int.tryParse(resolution?.group(2) ?? '') ?? 0;
      final width = int.tryParse(resolution?.group(1) ?? '');
      final bandwidth = int.tryParse(bandwidthMatch?.group(1) ?? '');
      qualities.add(
        PlayerVideoQuality.fromHls(
          playlistUrl: masterUri.resolve(uriLine).toString(),
          height: height,
          width: width,
          bandwidth: bandwidth,
        ),
      );
    }
    final unique = <String, PlayerVideoQuality>{};
    for (final quality in qualities) {
      final previous = unique[quality.id];
      if (previous == null ||
          (quality.bandwidth ?? 0) > (previous.bandwidth ?? 0)) {
        unique[quality.id] = quality;
      }
    }
    final result = unique.values.toList()
      ..sort((left, right) => right.height.compareTo(left.height));
    return List.unmodifiable(result);
  }

  static String? _nextUriLine(List<String> lines, int start) {
    for (var index = start; index < lines.length; index += 1) {
      final line = lines[index];
      if (line.isEmpty) continue;
      if (line.startsWith('#')) return null;
      return line;
    }
    return null;
  }
}
