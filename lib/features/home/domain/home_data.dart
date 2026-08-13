class HomeData {
  const HomeData({
    required this.id,
    required this.name,
    required this.status,
    required this.tabs,
  });

  final int id;
  final String name;
  final int status;
  final List<HomeTab> tabs;

  HomeData copyWith({int? id, String? name, int? status, List<HomeTab>? tabs}) {
    return HomeData(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      tabs: tabs ?? this.tabs,
    );
  }
}

class HomeTab {
  const HomeTab({
    required this.id,
    required this.name,
    required this.flag,
    required this.sort,
    required this.status,
    required this.page,
    required this.pageSize,
    required this.dramaTotal,
    required this.dramas,
  });

  final int id;
  final String name;
  final String flag;
  final int sort;
  final int status;
  final int page;
  final int pageSize;
  final int dramaTotal;
  final List<HomeDrama> dramas;

  bool get hasMoreDramas => dramas.length < dramaTotal;

  int get nextPage => page + 1;

  HomeTab copyWith({
    int? id,
    String? name,
    String? flag,
    int? sort,
    int? status,
    int? page,
    int? pageSize,
    int? dramaTotal,
    List<HomeDrama>? dramas,
  }) {
    return HomeTab(
      id: id ?? this.id,
      name: name ?? this.name,
      flag: flag ?? this.flag,
      sort: sort ?? this.sort,
      status: status ?? this.status,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      dramaTotal: dramaTotal ?? this.dramaTotal,
      dramas: dramas ?? this.dramas,
    );
  }
}

class HomeDrama {
  const HomeDrama({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.playCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    required this.episodeTotal,
    required this.tags,
    this.isFavorited = false,
    this.watchProgress,
  });

  final String id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final int playCount;
  final int trailerEpisodeNum;
  final bool isVipOnly;
  final int status;
  final int episodeTotal;
  final List<String> tags;
  final bool isFavorited;
  final HomeWatchProgress? watchProgress;
}

class HomeWatchProgress {
  const HomeWatchProgress({
    required this.episodeId,
    required this.episodeNo,
    required this.positionSeconds,
    required this.progressPercent,
    required this.durationSeconds,
  });

  final String episodeId;
  final int episodeNo;
  final int positionSeconds;
  final int progressPercent;
  final int durationSeconds;

  int get watchSecond => positionSeconds;
  int get durationSecond => durationSeconds;

  bool get hasHistory => episodeId != '0' && positionSeconds > 0;

  bool get canResume {
    if (!hasHistory || durationSeconds <= 0) {
      return false;
    }
    return positionSeconds < durationSeconds - 2;
  }
}
