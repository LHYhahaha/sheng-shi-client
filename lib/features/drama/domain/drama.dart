class DramaCategory {
  const DramaCategory({required this.id, required this.title});

  final String id;
  final String title;
}

class Drama {
  const Drama({
    required this.id,
    required this.title,
    required this.coverAssetPath,
    required this.viewCountLabel,
    required this.episodeCount,
    required this.categoryId,
    required this.tags,
    required this.coverAspectRatio,
    this.isExclusive = false,
  });

  final String id;
  final String title;
  final String coverAssetPath;
  final String viewCountLabel;
  final int episodeCount;
  final String categoryId;
  final List<String> tags;
  final double coverAspectRatio;
  final bool isExclusive;
}

class DramaFeedPage {
  const DramaFeedPage({required this.items, required this.nextPageToken});

  final List<Drama> items;
  final String? nextPageToken;
}
