import '../domain/my_list_item.dart';
import '../domain/my_list_repository.dart';
import 'mapper/my_list_mapper.dart';
import 'remote/my_list_remote_data_source.dart';

/// My list 远程 repository 骨架。
///
/// 默认 provider 仍走 mock；该实现只用于 remote 开关或测试。controller/UI 仍只依赖
/// MyListRepository，不接触 DTO、ApiClient 或 datasource。
class RemoteMyListRepository implements MyListRepository {
  const RemoteMyListRepository({
    required MyListRemoteDataSource remoteDataSource,
    MyListMapper mapper = const MyListMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final MyListRemoteDataSource _remoteDataSource;
  final MyListMapper _mapper;

  @override
  Future<List<MyListItem>> fetchItems({required MyListTab tab}) async {
    return switch (tab) {
      MyListTab.collection => _fetchFavorites(),
      MyListTab.play => _fetchPlayHistory(),
    };
  }

  Future<List<MyListItem>> _fetchFavorites() async {
    final page = await _remoteDataSource.listFavorites();
    return page.items.map(_mapper.mapFavorite).toList(growable: false);
  }

  Future<List<MyListItem>> _fetchPlayHistory() async {
    final page = await _remoteDataSource.listPlayHistory();
    return page.items.map(_mapper.mapPlayHistory).toList(growable: false);
  }

  @override
  Future<void> deleteFavorite({required int dramaId}) async {
    await _remoteDataSource.deleteFavorite(dramaId: dramaId);
  }

  @override
  Future<void> deleteFavorites({required List<int> dramaIds}) async {
    await _remoteDataSource.deleteFavorites(dramaIds: dramaIds);
  }

  @override
  Future<void> deletePlayHistory({required int historyId}) async {
    await _remoteDataSource.deletePlayHistory(historyId: historyId);
  }

  @override
  Future<void> deletePlayHistories({required List<int> historyIds}) async {
    await _remoteDataSource.deletePlayHistories(historyIds: historyIds);
  }
}
