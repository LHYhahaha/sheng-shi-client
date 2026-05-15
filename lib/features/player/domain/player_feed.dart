import 'player_content.dart';

/// 播放 feed 类型。
///
/// 单剧 feed 和 For You feed 的 session、进度保存和预热策略不同，不能只用一个布尔
/// 在 UI 层临时判断。
enum PlayerFeedMode { singleDrama, forYou }

/// 播放 feed 加载配置。
///
/// 配置描述“要加载哪种 feed”，不携带播放 source。source resolve 必须在 playback
/// controller 内完成，才能统一 locked/unavailable 和 timing trace。
class PlayerFeedConfig {
  const PlayerFeedConfig.singleDrama({
    required this.dramaId,
    required this.episodeId,
  }) : mode = PlayerFeedMode.singleDrama;

  const PlayerFeedConfig.forYou()
    : mode = PlayerFeedMode.forYou,
      dramaId = null,
      episodeId = null;

  /// feed 模式。
  ///
  /// 决定 repository 分支、session key 语义、进度保存和预热配置。
  final PlayerFeedMode mode;

  /// 单剧 feed 的剧 id。
  ///
  /// For You feed 下为空。不要在 For You 下读取它构造 route。
  final String? dramaId;

  /// 单剧 feed 的初始 episode id。
  ///
  /// 只用于定位初始集；后续 PageView 当前集由 PlayerFeedState.currentIndex 管理。
  final String? episodeId;

  @override
  bool operator ==(Object other) {
    return other is PlayerFeedConfig &&
        other.mode == mode &&
        other.dramaId == dramaId &&
        other.episodeId == episodeId;
  }

  @override
  int get hashCode => Object.hash(mode, dramaId, episodeId);
}

/// 播放 feed 中的一个可展示 item。
///
/// item 同时携带 content 和当前 episode，便于 PageView 渲染；但能不能播放仍取决于
/// episode 状态和 source repository 的 resolve 结果。
class PlayerFeedItem {
  const PlayerFeedItem({
    required this.id,
    required this.mode,
    required this.content,
    required this.episode,
  });

  /// feed item id。
  ///
  /// playback controller、preload state、prepared window 都用它做匹配。必须随 content
  /// 和 episode 稳定生成，不能用列表 index。
  final String id;

  /// item 所属 feed 模式。
  ///
  /// preload 配置会根据 For You/单剧走不同 count。
  final PlayerFeedMode mode;

  /// item 对应的剧内容。
  ///
  /// 供播放器 chrome 和详情弹层展示；不能从这里直接推断播放授权。
  final PlayerContent content;

  /// item 当前播放/展示的 episode。
  ///
  /// 选集时可能替换当前 item 的 episode，但 source 仍需重新 resolve。
  final PlayerEpisode episode;

  PlayerFeedItem copyWith({PlayerEpisode? episode}) {
    return PlayerFeedItem(
      id: id,
      mode: mode,
      content: content,
      episode: episode ?? this.episode,
    );
  }
}

/// 播放 feed 仓库边界。
///
/// 只负责返回 item 顺序和初始 episode，不做 HLS preload，也不持有播放器 session。
abstract interface class PlayerFeedRepository {
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  });

  Future<List<PlayerFeedItem>> listForYouFeed();
}
