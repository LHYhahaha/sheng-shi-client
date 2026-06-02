/// 首页数据模型。
class HomeData {
  const HomeData({
    required this.id,
    required this.name,
    required this.status,
    required this.tabs,
  });

  /// 首页模板 ID。
  final int id;

  /// 首页模板名称。
  final String name;

  /// 首页模板状态。
  final int status;

  /// 首页标签页列表。
  final List<HomeTab> tabs;
}

/// 首页标签页模型。
class HomeTab {
  const HomeTab({
    required this.id,
    required this.name,
    required this.flag,
    required this.sort,
    required this.status,
    required this.dramas,
  });

  /// 标签页 ID。
  final int id;

  /// 标签页名称。
  final String name;

  /// 标签页标志。
  final String flag;

  /// 排序值。
  final int sort;

  /// 状态。
  final int status;

  /// 该标签页下的剧卡列表。
  final List<HomeDrama> dramas;
}

/// 首页剧卡模型。
class HomeDrama {
  const HomeDrama({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.playCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    required this.episodeTotal,
    required this.tags,
  });

  /// 剧 ID。
  final String id;

  /// 排序值。
  final int sort;

  /// 封面 URL。
  final String coverUrl;

  /// 剧标题。
  final String title;

  /// 剧简介。
  final String summary;

  /// 播放次数。
  final int playCount;

  /// 预告集数。
  final int trailerEpisodeNum;

  /// 是否仅 VIP 可看。
  final bool isVipOnly;

  /// 状态。
  final int status;

  /// 总集数。
  final int episodeTotal;

  /// 剧标签列表。
  final List<String> tags;
}
