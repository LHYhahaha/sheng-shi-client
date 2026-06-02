import 'drama.dart';

/// 首页剧集数据仓库边界。
///
/// 仓库只返回剧卡和分类，不返回播放器 source。Home 不能在这里创建 media session，
/// 播放授权和 source resolve 必须留给 player feature。
abstract interface class DramaRepository {
  /// 获取首页数据（包含所有 tabs 和对应的 dramas）。
  Future<List<DramaCategory>> getHomeData();
}
