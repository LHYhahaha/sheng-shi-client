import '../../domain/search_rankings.dart';
import '../../domain/search_results.dart';
import '../dto/search_ranking_response_dto.dart';
import '../dto/search_results_response_dto.dart';

class SearchMapper {
  const SearchMapper();

  SearchRanking mapRanking(SearchRankingResponseDto dto) {
    return SearchRanking(
      limit: dto.limit,
      dramas: dto.dramas.map(_mapDrama).toList(growable: false),
    );
  }

  SearchRankDrama _mapDrama(SearchRankDramaDto dto) {
    return SearchRankDrama(
      id: dto.id.toString(),
      sort: dto.sort,
      coverUrl: dto.coverUrl,
      title: dto.title,
      summary: dto.summary,
      tags: dto.tagsName,
      searchCount: dto.searchCount,
      hotValue: dto.hotValue,
      trailerEpisodeNum: dto.trailerEpisodeNum,
      isVipOnly: dto.isVipOnly == 1,
      status: dto.status,
      watchProgress: dto.watchProgress?.toDomain(),
      trial: dto.trial?.toDomain(),
    );
  }

  SearchResults mapResults(SearchResultsResponseDto dto) {
    return SearchResults(
      keyword: dto.keyword,
      page: dto.page,
      pageSize: dto.pageSize,
      total: dto.total,
      dramas: dto.dramas.map(_mapResultDrama).toList(growable: false),
      guessLike: dto.guessLike.map(_mapResultDrama).toList(growable: false),
    );
  }

  SearchResultDrama _mapResultDrama(SearchResultDramaDto dto) {
    return SearchResultDrama(
      id: dto.id.toString(),
      sort: dto.sort,
      coverUrl: dto.coverUrl,
      title: dto.title,
      summary: dto.summary,
      tags: dto.tagsName,
      categories: dto.categoryNames,
      playCount: dto.playCount,
      trailerEpisodeNum: dto.trailerEpisodeNum,
      isVipOnly: dto.isVipOnly == 1,
      status: dto.status,
      episodeTotal: dto.episodeTotal,
      watchProgress: dto.watchProgress?.toDomain(),
      trial: dto.trial?.toDomain(),
    );
  }
}
