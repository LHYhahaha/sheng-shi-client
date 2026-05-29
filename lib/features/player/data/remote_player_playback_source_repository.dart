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
    // 直接使用 episode.videoSource（来自首页 API 的 source_url），无需调用 playback-source API
    final remoteUrl = item.episode.videoSource;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      throw StateError('Episode has no playable source.');
    }

    return PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: remoteUrl,
      cacheKey: _cacheKey(item),
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      codecHint: 'hls',
      status: PlaybackSourceStatus.resolved,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(PlayerFeedItem item) async {
    // 直接使用 episode.videoSource，无需调用 playback-source API
    final remoteUrl = item.episode.videoSource;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: '',
        status: PlaybackPreloadStatus.failed,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        error: StateError('Episode has no playable source.'),
      );
    }

    final source = PlaybackSource(
      itemId: item.id,
      remoteUrl: remoteUrl,
      playableSource: remoteUrl,
      cacheKey: _cacheKey(item),
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      codecHint: 'hls',
      status: PlaybackSourceStatus.preloaded,
    );
    return _preloadManager.preload(item: item, source: source);
  }

  String _cacheKey(PlayerFeedItem item) {
    return 'player:${item.content.id}:${item.episode.id}';
  }
}
