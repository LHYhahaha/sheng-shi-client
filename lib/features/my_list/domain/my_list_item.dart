/// 片单 tab。
///
/// collection 支持批量编辑，play 支持单行滑动删除，两者交互不能混用。
enum MyListTab { collection, play }

/// 片单条目。
///
/// 该模型同时服务收藏列表和播放列表，当前只包含展示字段。真实接入后删除/播放历史
/// 状态应通过 repository 返回，不要让 UI 自行拼接。
class MyListItem {
  const MyListItem({
    required this.id,
    required this.title,
    required this.introduction,
    required this.coverAssetPath,
    required this.currentEpisode,
    required this.episodeCount,
  });

  /// 条目 id。
  ///
  /// 用于选择、删除和 slidable open state，不能用列表 index 替代。
  final String id;

  /// 剧名或条目标题。
  final String title;

  /// 简介文案。
  ///
  /// 只用于列表展示，不参与搜索或排序。
  final String introduction;

  /// 封面 asset 路径。
  final String coverAssetPath;

  /// 当前观看到的集数。
  ///
  /// 用于播放列表进度展示，不代表真实播放进度；播放进度由 player progress 记录。
  final int currentEpisode;

  /// 总集数。
  ///
  /// 只用于展示“当前/总集数”。
  final int episodeCount;
}
