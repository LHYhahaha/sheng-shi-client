/// A selectable HLS video rendition for one episode.
///
/// `playlistUrl` is the media playlist for a manual selection.  Automatic
/// playback keeps using the master playlist, allowing the HLS player to make
/// normal adaptive-bitrate decisions.
class PlayerVideoQuality {
  const PlayerVideoQuality({
    required this.id,
    required this.label,
    required this.playlistUrl,
    required this.height,
    this.width,
    this.bandwidth,
  });

  final String id;
  final String label;
  final String playlistUrl;
  final int height;
  final int? width;
  final int? bandwidth;

  /// 1080p is member-only only when the episode offers another rendition.
  bool get is1080p => height >= 1080;

  bool get isMemberOnly => is1080p;

  static const automaticId = 'auto';
  static const automaticLabel = '自动';

  static PlayerVideoQuality fromHls({
    required String playlistUrl,
    required int height,
    int? width,
    int? bandwidth,
  }) {
    final normalizedHeight = height < 0 ? 0 : height;
    return PlayerVideoQuality(
      id: normalizedHeight == 0 ? 'unknown' : '${normalizedHeight}p',
      label: normalizedHeight == 0 ? '原画' : '${normalizedHeight}p',
      playlistUrl: playlistUrl,
      height: normalizedHeight,
      width: width,
      bandwidth: bandwidth,
    );
  }
}

/// Result returned to the presentation layer after it asks to switch quality.
/// Routing to membership remains a UI concern.
enum PlayerVideoQualitySelectionResult {
  switched,
  requiresMembership,
  unavailable,
  failed,
}
