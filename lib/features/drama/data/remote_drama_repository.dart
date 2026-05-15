import '../domain/drama.dart';
import '../domain/drama_repository.dart';
import 'mapper/drama_mapper.dart';
import 'remote/drama_remote_data_source.dart';

/// Home/Drama 真实接口 repository 骨架。
///
/// 该实现当前不会作为默认数据源启用，只用于打通 remote datasource -> DTO -> mapper
/// 的迁移路径。页面仍通过 DramaRepository 读取 domain model，不感知远程 DTO。
class RemoteDramaRepository implements DramaRepository {
  const RemoteDramaRepository({
    required DramaRemoteDataSource remoteDataSource,
    DramaMapper mapper = const DramaMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final DramaRemoteDataSource _remoteDataSource;
  final DramaMapper _mapper;

  @override
  Future<List<DramaCategory>> listHomeCategories() async {
    final categories = await _remoteDataSource.listHomeCategories();
    return categories.map(_mapper.mapCategory).toList(growable: false);
  }

  @override
  Future<DramaFeedPage> listHomeFeed({
    required String categoryId,
    String? pageToken,
    int pageSize = 10,
  }) async {
    final page = await _remoteDataSource.listHomeFeed(
      categoryId: categoryId,
      pageToken: pageToken,
      pageSize: pageSize,
    );
    return _mapper.mapFeedPage(page);
  }
}
