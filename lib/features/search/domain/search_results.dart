import '../../drama/domain/drama_trial.dart';
import '../../drama/domain/drama_watch_progress.dart';

enum SearchSortType {
  hottest('hottest'),
  newest('newest'),
  unwatched('unwatched');

  const SearchSortType(this.value);

  final String value;
}

class SearchResults {
  const SearchResults({
    required this.keyword,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.dramas,
    required this.guessLike,
  });

  final String keyword;
  final int page;
  final int pageSize;
  final int total;
  final List<SearchResultDrama> dramas;
  final List<SearchResultDrama> guessLike;
}

class SearchResultDrama {
  const SearchResultDrama({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.tags,
    required this.categories,
    required this.playCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    required this.episodeTotal,
    this.watchProgress,
    this.trial,
  });

  final String id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final List<String> tags;
  final List<String> categories;
  final int playCount;
  final int trailerEpisodeNum;
  final bool isVipOnly;
  final int status;
  final int episodeTotal;
  final DramaWatchProgress? watchProgress;
  final DramaTrial? trial;
}
