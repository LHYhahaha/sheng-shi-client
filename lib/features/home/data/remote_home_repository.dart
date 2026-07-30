import '../domain/home_data.dart';
import '../domain/vip_only_drama.dart';
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
  Future<List<String>> getHotSearchKeywords() async {
    final ranking = await _remoteDataSource.getHotSearchKeywords();
    final keywords = <String>[];
    final seen = <String>{};
    for (final drama in ranking.dramas) {
      final title = drama.title.trim();
      if (title.isEmpty || !seen.add(title)) continue;
      keywords.add(title);
    }
    return List.unmodifiable(keywords);
  }

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

  @override
  Future<VipOnlyDramaCollection> getVipOnlyDramas() async {
    final dto = await _remoteDataSource.getVipOnlyDramas();
    return VipOnlyDramaCollection(
      limit: dto.limit,
      dramas: dto.dramas
          .where((drama) => drama.id > 0)
          .map(
            (drama) => VipOnlyDrama(
              id: drama.id.toString(),
              coverUrl: drama.coverUrl,
              title: drama.title,
              summary: drama.summary,
            ),
          )
          .toList(growable: false),
    );
  }
}
