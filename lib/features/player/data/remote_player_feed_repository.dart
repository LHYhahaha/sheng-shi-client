import '../domain/player_feed.dart';
import 'mapper/player_content_mapper.dart';
import 'mapper/player_feed_mapper.dart';
import 'remote/player_remote_data_source.dart';

/// 播放 feed 远程 repository。
class RemotePlayerFeedRepository implements PlayerFeedRepository {
  const RemotePlayerFeedRepository({
    required PlayerRemoteDataSource remoteDataSource,
    PlayerFeedMapper feedMapper = const PlayerFeedMapper(),
    PlayerContentMapper contentMapper = const PlayerContentMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _feedMapper = feedMapper,
       _contentMapper = contentMapper;

  final PlayerRemoteDataSource _remoteDataSource;
  final PlayerFeedMapper _feedMapper;
  final PlayerContentMapper _contentMapper;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    final dramaIdInt = int.tryParse(dramaId) ?? 0;
    final dto = await _remoteDataSource.fetchDramaDetail(dramaId: dramaIdInt);
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
    final page = await _remoteDataSource.listForYouFeed();
    return page.items.map(_feedMapper.mapForYouItem).toList(growable: false);
  }

}
