import '../domain/home_data.dart';
import '../domain/vip_only_drama.dart';

/// 首页数据仓库接口。
abstract interface class HomeRepository {
  /// 获取首页搜索框展示的热搜关键词。
  Future<List<String>> getHotSearchKeywords();

  /// 获取首页数据。
  ///
  /// 需要登录后的 token。
  Future<HomeData> getHomeData({int? page, int pageSize = 20, int? tabId});

  /// 获取会员相关页面共用的会员专享短剧列表。
  Future<VipOnlyDramaCollection> getVipOnlyDramas();
}
