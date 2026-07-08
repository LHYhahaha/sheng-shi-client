enum PopupPlacementCode {
  homeEnter('home_enter'),
  recommendTabEnter('recommend_tab_enter');

  const PopupPlacementCode(this.apiValue);

  final String apiValue;
}

class PopupConfig {
  const PopupConfig({
    this.id,
    this.name,
    this.placementCode,
    this.contentMode,
    this.popupImage,
    this.showCloseButton,
    this.jumpType,
    this.h5Url,
    this.pageCode,
    this.shortJumpMode,
    this.shortDramaId,
  });

  final int? id;
  final String? name;
  final String? placementCode;
  final int? contentMode;
  final String? popupImage;
  final int? showCloseButton;
  final int? jumpType;
  final String? h5Url;
  final String? pageCode;
  final int? shortJumpMode;
  final int? shortDramaId;
}

class PopupExitRecommendation {
  const PopupExitRecommendation({
    required this.id,
    required this.sort,
    required this.coverUrl,
    required this.title,
    required this.summary,
    required this.tagsName,
    required this.categoryNames,
    required this.playCount,
    required this.trailerEpisodeNum,
    required this.isVipOnly,
    required this.status,
    required this.episodeTotal,
  });

  final int id;
  final int sort;
  final String coverUrl;
  final String title;
  final String summary;
  final List<String> tagsName;
  final List<String> categoryNames;
  final int playCount;
  final int trailerEpisodeNum;
  final int isVipOnly;
  final int status;
  final int episodeTotal;
}
