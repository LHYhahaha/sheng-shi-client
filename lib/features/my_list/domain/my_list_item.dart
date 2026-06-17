import '../../../shared/media/media_resource.dart';

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
    required this.dramaId,
    required this.title,
    required this.introduction,
    required this.coverAssetPath,
    required this.currentEpisode,
    required this.episodeCount,
    MediaResource? coverResource,
    this.episodeId,
    this.watchSecond,
    this.dramaStatus,
  }) : _coverResource = coverResource;

  /// My list 默认封面兜底。
  ///
  /// 远程接口缺图或网络图加载失败时仍能保持当前 UI 可展示。后续如果抽统一图片组件，
  /// 可以把这个兜底迁移到 shared media 层。
  static const fallbackCoverAssetPath = 'assets/images/my_list/cover_1.png';

  /// 条目 dramaId。
  ///
  /// 用于选择、删除和 slidable open state，是唯一标识，不能用列表 index 替代。
  final int dramaId;

  /// 剧名或条目标题。
  final String title;

  /// 简介文案。
  ///
  /// 只用于列表展示，不参与搜索或排序。
  final String introduction;

  /// 封面 asset 路径。
  final String coverAssetPath;

  /// 封面的统一资源身份。
  ///
  /// remote mapper 会把 coverUrl 映射为 network resource。当前 MyListPage 仍使用
  /// coverAssetPath 渲染，避免本轮扩大 UI 改动；后续切网络图时应优先读此字段。
  MediaResource get coverResource =>
      _coverResource ?? MediaResource.asset(coverAssetPath);

  final MediaResource? _coverResource;

  /// 当前观看到的集数。
  ///
  /// 用于播放列表进度展示，不代表真实播放进度；播放进度由 player progress 记录。
  final int currentEpisode;

  /// 总集数。
  ///
  /// 只用于展示"当前/总集数"。
  final int episodeCount;

  /// 集数id。
  final int? episodeId;

  /// 观看时间。
  final int? watchSecond;

  /// 短剧在架状态。
  ///
  /// 1: 已上架，2: 已下架。已下架的短剧点击需提示用户并禁止跳转。
  final int? dramaStatus;
}
