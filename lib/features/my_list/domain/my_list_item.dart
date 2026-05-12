enum MyListTab { collection, play }

class MyListItem {
  const MyListItem({
    required this.id,
    required this.title,
    required this.introduction,
    required this.coverAssetPath,
    required this.currentEpisode,
    required this.episodeCount,
  });

  final String id;
  final String title;
  final String introduction;
  final String coverAssetPath;
  final int currentEpisode;
  final int episodeCount;
}
