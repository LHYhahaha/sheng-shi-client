import 'playback_media.dart';

/// 早期播放仓库抽象。
///
/// 保留它是为了兼容后续可能的媒体详情接口，但当前核心播放链路使用
/// PlayerPlaybackSourceRepository；新增代码不要绕过新的 source/preload 状态机。
abstract interface class PlaybackRepository {
  Future<PlaybackMedia> getPlaybackMedia({
    required String dramaId,
    required String episodeId,
  });
}
