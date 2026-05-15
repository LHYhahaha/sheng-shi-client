import '../domain/player_content.dart';
import '../domain/player_feed.dart';

/// 播放 feed mock 仓库。
///
/// 它负责把内容 mock 组装成单剧/For You feed，不负责 source resolve。这样测试能覆盖
/// “feed item -> playback controller -> source repository”的真实调用链。
class MockPlayerFeedRepository implements PlayerFeedRepository {
  const MockPlayerFeedRepository({required this.contentRepository});

  final PlayerContentRepository contentRepository;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    final content = await contentRepository.getPlayerContent(dramaId: dramaId);
    final items = content.episodes
        .map((episode) {
          return PlayerFeedItem(
            id: '${content.id}-${episode.id}',
            mode: PlayerFeedMode.singleDrama,
            content: content,
            episode: episode,
          );
        })
        .toList(growable: false);

    final initialIndex = _episodeIndex(items, episodeId);
    if (initialIndex <= 0) {
      return items;
    }

    return [...items.sublist(initialIndex), ...items.sublist(0, initialIndex)];
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
    final specs = [
      const _ForYouSpec(dramaId: 'found-you', episodeNumber: 1),
      const _ForYouSpec(dramaId: 'heart-thief', episodeNumber: 2),
      const _ForYouSpec(dramaId: 'reborn-love', episodeNumber: 3),
      const _ForYouSpec(dramaId: 'secret-vow', episodeNumber: 5),
      const _ForYouSpec(dramaId: 'asian-reunion', episodeNumber: 8),
      const _ForYouSpec(dramaId: 'heart-thief', episodeNumber: 12),
    ];

    final items = <PlayerFeedItem>[];
    for (final spec in specs) {
      final content = await contentRepository.getPlayerContent(
        dramaId: spec.dramaId,
      );
      final episode = content.episodes.firstWhere(
        (episode) => episode.number == spec.episodeNumber,
        orElse: () => content.episodes.first,
      );
      items.add(
        PlayerFeedItem(
          id: 'for-you-${content.id}-${episode.id}',
          mode: PlayerFeedMode.forYou,
          content: content,
          episode: episode,
        ),
      );
    }

    return List<PlayerFeedItem>.unmodifiable(items);
  }

  int _episodeIndex(List<PlayerFeedItem> items, String episodeId) {
    final requestedNumber = int.tryParse(episodeId);
    return items.indexWhere((item) {
      return item.episode.id == episodeId ||
          item.episode.number == requestedNumber;
    });
  }
}

class _ForYouSpec {
  const _ForYouSpec({required this.dramaId, required this.episodeNumber});

  final String dramaId;
  final int episodeNumber;
}
