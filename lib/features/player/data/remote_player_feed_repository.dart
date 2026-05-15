import '../domain/player_feed.dart';
import 'dto/player_content_dto.dart';
import 'mapper/player_content_mapper.dart';
import 'mapper/player_feed_mapper.dart';
import 'remote/player_remote_data_source.dart';

/// 播放 feed 远程 repository 骨架。
class RemotePlayerFeedRepository implements PlayerFeedRepository {
  const RemotePlayerFeedRepository({
    required PlayerRemoteDataSource remoteDataSource,
    PlayerContentMapper contentMapper = const PlayerContentMapper(),
    PlayerFeedMapper feedMapper = const PlayerFeedMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _contentMapper = contentMapper,
       _feedMapper = feedMapper;

  final PlayerRemoteDataSource _remoteDataSource;
  final PlayerContentMapper _contentMapper;
  final PlayerFeedMapper _feedMapper;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    final detail = await _remoteDataSource.getDramaDetail(dramaId: dramaId);
    final episodes = await _remoteDataSource.listEpisodes(dramaId: dramaId);
    final content = _contentMapper.mapContent(
      PlayerContentDto(
        dramaId: detail.dramaId,
        title: detail.title,
        description: detail.description,
        posterUrl: detail.posterUrl,
        backgroundUrl: detail.backgroundUrl,
        totalEpisodes: detail.totalEpisodes,
        tags: detail.tags,
        viewCount: detail.viewCount,
        viewCountLabel: detail.viewCountLabel,
        likeCountLabel: detail.likeCountLabel,
        episodes: episodes,
      ),
    );

    final items = content.episodes
        .map(
          (episode) => PlayerFeedItem(
            id: 'single:${content.id}:${episode.id}',
            mode: PlayerFeedMode.singleDrama,
            content: content,
            episode: episode,
          ),
        )
        .toList(growable: false);
    final initialIndex = _episodeIndex(items, episodeId);
    if (initialIndex <= 0) return items;
    return [...items.sublist(initialIndex), ...items.sublist(0, initialIndex)];
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
    final page = await _remoteDataSource.listForYouFeed();
    return page.items.map(_feedMapper.mapForYouItem).toList(growable: false);
  }

  int _episodeIndex(List<PlayerFeedItem> items, String episodeId) {
    final requestedNumber = int.tryParse(episodeId);
    return items.indexWhere(
      (item) =>
          item.episode.id == episodeId ||
          item.episode.number == requestedNumber,
    );
  }
}
