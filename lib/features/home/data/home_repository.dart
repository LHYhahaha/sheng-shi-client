import '../domain/home_data.dart';

/// 首页数据仓库接口。
abstract interface class HomeRepository {
  /// 获取首页数据。
  ///
  /// 需要登录后的 token。
  Future<HomeData> getHomeData();
}
