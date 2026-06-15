import '../domain/home_data.dart';
import 'home_repository.dart';
import 'mapper/home_mapper.dart';
import 'remote/home_remote_data_source.dart';

/// 首页远程 repository 实现。
///
/// 负责调用远程接口获取首页数据，并通过 mapper 转换为 domain model。
class RemoteHomeRepository implements HomeRepository {
  const RemoteHomeRepository({
    required HomeRemoteDataSource remoteDataSource,
    HomeMapper mapper = const HomeMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final HomeRemoteDataSource _remoteDataSource;
  final HomeMapper _mapper;

  @override
  Future<HomeData> getHomeData({
    int? page,
    int pageSize = 20,
    int? tabId,
  }) async {
    final dto = await _remoteDataSource.getHomeData(
      page: page,
      pageSize: pageSize,
      tabId: tabId,
    );

    return _mapper.mapHomeData(dto);
  }
}
