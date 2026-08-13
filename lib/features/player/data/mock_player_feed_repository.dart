import '../domain/player_feed.dart';
import 'mock_player_content_repository.dart';

/// 本地播放器 feed。
///
/// 单剧播放页加载的是 [PlayerFeedRepository]，不能只切换 content repository；否则
/// `USE_REMOTE_PLAYER_API=false` 仍会从远端详情接口取得剧集和解锁状态。
class MockPlayerFeedRepository implements PlayerFeedRepository {
  const MockPlayerFeedRepository({
    this.contentRepository = const MockPlayerContentRepository(),
  });

  final MockPlayerContentRepository contentRepository;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    final content = await contentRepository.getPlayerContent(dramaId: dramaId);
    return content.episodes
        .map(
          (episode) => PlayerFeedItem(
            id: 'single:${content.id}:${episode.id}',
            mode: PlayerFeedMode.singleDrama,
            content: content,
            episode: episode,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
    final content = await contentRepository.getPlayerContent(
      dramaId: 'found-you',
    );
    return content.episodes
        .take(8)
        .map(
          (episode) => PlayerFeedItem(
            id: 'for-you:${content.id}:${episode.id}',
            mode: PlayerFeedMode.forYou,
            content: content,
            episode: episode,
          ),
        )
        .toList(growable: false);
  }
}
