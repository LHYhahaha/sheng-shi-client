import 'my_list_item.dart';

abstract interface class MyListRepository {
  Future<List<MyListItem>> fetchItems({required MyListTab tab});

  /// 删除单个收藏。
  ///
  /// 当前 UI 仍做本地乐观删除，remote skeleton 先把 mutation 边界放进 repository。
  /// 真实接入后 controller 可在这里统一做失败回滚。
  Future<void> deleteFavorite({required String dramaId});

  /// 批量删除收藏。
  ///
  /// 服务端应保证幂等：已经删除的条目不应让客户端进入异常状态。本轮只透传
  /// ApiException，业务码策略后续再细化。
  Future<void> deleteFavorites({required List<String> dramaIds});

  /// 删除播放历史。
  ///
  /// historyId 来自播放历史接口；如果服务端暂不返回 historyId，mapper 会用
  /// dramaId + episodeId 生成稳定展示 id，但远程删除仍优先使用真实 historyId。
  Future<void> deletePlayHistory({required String historyId});
}
