import '../../drama/domain/drama_watch_progress.dart';

/// 搜索页三个榜单的聚合数据。
class SearchRankings {
  const SearchRankings({
    required this.hotSearches,
    required this.hotPlays,
    required this.newOnline,
  });

  final SearchRanking hotSearches;
  final SearchRanking hotPlays;
  final SearchRanking newOnline;
}

/// 单个榜单。
class SearchRanking {
  const SearchRanking({required this.limit, required this.dramas});

  final int limit;
  final List<SearchRankDrama> dramas;
}

/// 搜索页榜单剧集。
class SearchRankDrama {
  const SearchRankDrama({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.tags,
    required this.searchCount,
    required this.hotValue,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    this.watchProgress,
  });

  final String id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final List<String> tags;
  final int searchCount;
  final int hotValue;
  final int trailerEpisodeNum;
  final bool isVipOnly;
  final int status;
  final DramaWatchProgress? watchProgress;
}
