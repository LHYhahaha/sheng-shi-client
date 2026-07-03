import '../domain/search_rankings.dart';
import '../domain/search_repository.dart';
import '../domain/search_results.dart';
import 'mapper/search_mapper.dart';
import 'remote/search_remote_data_source.dart';

class RemoteSearchRepository implements SearchRepository {
  const RemoteSearchRepository({
    required SearchRemoteDataSource remoteDataSource,
    SearchMapper mapper = const SearchMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final SearchRemoteDataSource _remoteDataSource;
  final SearchMapper _mapper;

  @override
  Future<SearchRanking> getHotSearches() async {
    return _mapper.mapRanking(await _remoteDataSource.getHotSearches());
  }

  @override
  Future<SearchRanking> getHotPlays() async {
    return _mapper.mapRanking(await _remoteDataSource.getHotPlays());
  }

  @override
  Future<SearchRanking> getNewOnline() async {
    return _mapper.mapRanking(await _remoteDataSource.getNewOnline());
  }

  @override
  Future<SearchRankings> getRankings() async {
    final responses = await Future.wait([
      getHotSearches(),
      getHotPlays(),
      getNewOnline(),
    ]);

    return SearchRankings(
      hotSearches: responses[0],
      hotPlays: responses[1],
      newOnline: responses[2],
    );
  }

  @override
  Future<SearchResults> search({
    required String keyword,
    String page = '1',
    String pageSize = '20',
    SearchSortType? sortType,
  }) async {
    final response = await _remoteDataSource.search(
      keyword: keyword,
      page: page,
      pageSize: pageSize,
      sortType: sortType?.value,
    );
    return _mapper.mapResults(response);
  }
}
