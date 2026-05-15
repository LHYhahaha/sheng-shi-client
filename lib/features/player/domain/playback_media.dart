/// 播放媒体资源描述。
///
/// 这是通用 media 元信息，不承担授权或缓存职责。能否播放仍由 playback source resolve
/// 和播放器状态机决定。
class PlaybackMedia {
  const PlaybackMedia({
    required this.dramaId,
    required this.episodeId,
    required this.url,
  });

  /// 剧 id。
  final String dramaId;

  /// 集 id。
  final String episodeId;

  /// 媒体 URL。
  ///
  /// 这是通用媒体描述的 URL，不等同于 PlayerPlaybackSource.playableSource。
  final Uri url;
}
