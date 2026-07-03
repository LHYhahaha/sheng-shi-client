import '../domain/player_feed.dart';
import 'mapper/player_content_mapper.dart';
import 'mapper/player_feed_mapper.dart';
import 'player_drama_detail_cache.dart';
import 'remote/player_remote_data_source.dart';

/// 播放 feed 远程 repository。
class RemotePlayerFeedRepository
    implements PlayerFeedRepository, PagedForYouFeedRepository {
  const RemotePlayerFeedRepository({
    required PlayerRemoteDataSource remoteDataSource,
    PlayerDramaDetailCache? dramaDetailCache,
    PlayerFeedMapper feedMapper = const PlayerFeedMapper(),
    PlayerContentMapper contentMapper = const PlayerContentMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _dramaDetailCache = dramaDetailCache,
       _feedMapper = feedMapper,
       _contentMapper = contentMapper;

  final PlayerRemoteDataSource _remoteDataSource;
  final PlayerDramaDetailCache? _dramaDetailCache;
  final PlayerFeedMapper _feedMapper;
  final PlayerContentMapper _contentMapper;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    final dramaIdInt = int.tryParse(dramaId) ?? 0;
    final dto =
        await (_dramaDetailCache?.get(dramaIdInt) ??
            _remoteDataSource.fetchDramaDetail(dramaId: dramaIdInt));
    final content = _contentMapper.mapContent(dto);

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
    return items;
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
    final result = await listForYouFeedPage(page: 1);
    return result.items;
  }

  @override
  Future<PlayerFeedPage> listForYouFeedPage({
    required int page,
    int pageSize = 20,
  }) async {
    final dto = await _remoteDataSource.listForYouFeed(
      page: page,
      pageSize: pageSize,
    );
    final items = dto.items
        .map(_feedMapper.mapForYouItem)
        .toList(growable: false);
    return PlayerFeedPage(
      items: items,
      page: dto.page,
      pageSize: dto.pageSize,
      total: dto.total,
      hasMore: dto.hasMore && items.isNotEmpty,
    );
  }
}
