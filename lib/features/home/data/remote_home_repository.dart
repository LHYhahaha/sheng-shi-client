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
  Future<HomeData> getHomeData() async {
    print('[RemoteHomeRepository] getHomeData starting...');
    
    try {
      final dto = await _remoteDataSource.getHomeData();
      print('[RemoteHomeRepository] getHomeData received response');
      
      final homeData = _mapper.mapHomeData(dto);
      print('[RemoteHomeRepository] getHomeData mapped to domain model');
      print('[RemoteHomeRepository]   tabs count: ${homeData.tabs.length}');
      
      return homeData;
    } catch (e) {
      print('[RemoteHomeRepository] getHomeData error: $e');
      rethrow;
    }
  }
}
