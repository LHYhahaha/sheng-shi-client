class Drama {
  const Drama({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.episodeCount,
    required this.category,
    this.isExclusive = false,
  });

  final String id;
  final String title;
  final String coverUrl;
  final int episodeCount;
  final String category;
  final bool isExclusive;
}
