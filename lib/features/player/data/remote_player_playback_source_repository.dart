import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import 'mapper/playback_source_mapper.dart';
import 'remote/playback_source_remote_data_source.dart';

/// 播放源远程 repository 骨架。
///
/// 它实现现有 PlayerPlaybackSourceRepository，调用方无需知道 source 来自 mock 还是远程。
class RemotePlayerPlaybackSourceRepository
    implements PlayerPlaybackSourceRepository {
  const RemotePlayerPlaybackSourceRepository({
    required PlaybackSourceRemoteDataSource remoteDataSource,
    required PlayerPlaybackPreloadManager preloadManager,
    PlaybackSourceMapper mapper = const PlaybackSourceMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _preloadManager = preloadManager,
       _mapper = mapper;

  final PlaybackSourceRemoteDataSource _remoteDataSource;
  final PlayerPlaybackPreloadManager _preloadManager;
  final PlaybackSourceMapper _mapper;

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    final dto = await _remoteDataSource.getPlaybackSource(
      episodeId: item.episode.id,
    );
    return _mapper.mapSource(
      dto,
      item: item,
      status: PlaybackSourceStatus.resolved,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(PlayerFeedItem item) async {
    final dto = await _remoteDataSource.getPlaybackSource(
      episodeId: item.episode.id,
    );
    final source = _mapper.mapSource(
      dto,
      item: item,
      status: PlaybackSourceStatus.preloaded,
    );
    return _preloadManager.preload(item: item, source: source);
  }
}
