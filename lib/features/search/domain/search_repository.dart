import 'search_rankings.dart';
import 'search_results.dart';

abstract interface class SearchRepository {
  Future<SearchRanking> getHotSearches();

  Future<SearchRanking> getHotPlays();

  Future<SearchRanking> getNewOnline();

  Future<SearchRankings> getRankings();

  Future<SearchResults> search({
    required String keyword,
    String page = '1',
    String pageSize = '20',
    SearchSortType? sortType,
  });
}
