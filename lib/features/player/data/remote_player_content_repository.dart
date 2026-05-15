import '../domain/player_content.dart';
import 'dto/player_content_dto.dart';
import 'mapper/player_content_mapper.dart';
import 'remote/player_remote_data_source.dart';

/// 播放详情远程 repository 骨架。
///
/// 真实详情和 episode list 可以来自两个接口；repository 负责合并后再交给 mapper。
class RemotePlayerContentRepository implements PlayerContentRepository {
  const RemotePlayerContentRepository({
    required PlayerRemoteDataSource remoteDataSource,
    PlayerContentMapper mapper = const PlayerContentMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _mapper = mapper;

  final PlayerRemoteDataSource _remoteDataSource;
  final PlayerContentMapper _mapper;

  @override
  Future<PlayerContent> getPlayerContent({required String dramaId}) async {
    final detail = await _remoteDataSource.getDramaDetail(dramaId: dramaId);
    final episodes = await _remoteDataSource.listEpisodes(dramaId: dramaId);
    final combined = PlayerContentDto(
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
    );
    return _mapper.mapContent(combined);
  }
}
