import '../../../shared/media/media_resource.dart';

/// 首页分类模型。
///
/// 分类 id 是分页和首屏预热的稳定 key，展示标题可以多语言化，但不要用 title 反查分类。
class DramaCategory {
  const DramaCategory({required this.id, required this.title});

  /// 分类 id。
  ///
  /// 用于请求 feed 和保持选中态，必须稳定。
  final String id;

  /// 分类标题。
  ///
  /// 只用于展示，后续多语言变化不应影响分页请求。
  final String title;
}

/// 首页剧卡模型。
///
/// Home 只展示剧维度数据，不携带可播放 source。进入播放器前必须通过 player feed
/// 再解析 episode，避免首页提前触碰授权和媒体资源。
class Drama {
  Drama({
    required this.id,
    required this.title,
    required this.coverAssetPath,
    required this.viewCountLabel,
    required this.episodeCount,
    required this.categoryId,
    required this.tags,
    required this.coverAspectRatio,
    MediaResource? coverResource,
    this.isExclusive = false,
    this.watchProgress,
  }) : coverResource =
           coverResource ??
           MediaResource.asset(coverAssetPath, aspectRatio: coverAspectRatio);

  /// Home mock 默认封面。
  ///
  /// 远程接口缺图或网络图加载失败时作为安全兜底。后续接入全局占位图策略后，可以把
  /// 这个常量迁移到 shared media/image 组件中。
  static const fallbackCoverAssetPath =
      'assets/images/home/drama_cover_figma.png';

  /// 剧 id。
  ///
  /// 点击后用于加载单剧播放器 feed，不直接对应 episode source。
  final String id;

  /// 剧卡标题。
  final String title;

  /// 首页封面 asset 路径。
  ///
  /// 兼容旧 UI 和 mock 数据保留。新代码优先读取 `coverResource`，避免把远端 URL
  /// 伪装成 asset path。
  final String coverAssetPath;

  /// 首页封面的统一资源身份。
  ///
  /// 只表达 asset/network 与资源值，不负责加载策略。Home 渲染时根据 type 选择
  /// Image.asset 或 Image.network。
  final MediaResource coverResource;

  /// 播放量展示文案。
  ///
  /// 已格式化，不应在客户端解析数字做排序。
  final String viewCountLabel;

  /// 总集数展示值。
  ///
  /// 只用于卡片展示，播放器选集仍以 PlayerContent.episodes 为准。
  final int episodeCount;

  /// 所属分类 id。
  ///
  /// 用于 mock/接口分页过滤，不用于 UI 展示。
  final String categoryId;

  /// 剧卡标签。
  ///
  /// 仅展示，不作为推荐或权限判断。
  final List<String> tags;

  /// 首页封面比例。
  ///
  /// 用于 masonry 布局预留尺寸，避免图片加载时布局跳动。
  final double coverAspectRatio;

  /// 是否展示独家标记。
  ///
  /// 只是营销标签，不代表播放权限或会员锁定。
  final bool isExclusive;

  /// 首页接口随卡片下发的续播提示；不含播放地址，也不代表最终播放权限。
  final DramaWatchProgress? watchProgress;
}

class DramaWatchProgress {
  const DramaWatchProgress({
    required this.episodeId,
    required this.episodeNo,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  final String episodeId;
  final int episodeNo;
  final int positionSeconds;
  final int durationSeconds;

  bool get canResume {
    if (episodeId == '0' || positionSeconds <= 0 || durationSeconds <= 0) {
      return false;
    }
    return positionSeconds < durationSeconds - 2;
  }
}

/// 首页剧卡分页结果。
///
/// `nextPageToken` 为空才表示没有更多；items 为空可能只是当前分类暂无内容，不能
/// 当作分页结束策略复用到其他分类。
class DramaFeedPage {
  const DramaFeedPage({required this.items, required this.nextPageToken});

  /// 当前页剧卡列表。
  final List<Drama> items;

  /// 下一页游标。
  ///
  /// null 表示没有更多；非 null 时由 HomeFeedController 传回 repository。
  final String? nextPageToken;
}
