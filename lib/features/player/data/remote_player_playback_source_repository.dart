import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import 'mapper/playback_source_mapper.dart';
import 'remote/playback_source_remote_data_source.dart';
import 'hls_local_proxy_server.dart';
import 'hls_traffic_gate.dart';

/// 播放源远程 repository 骨架。
///
/// 它实现现有 PlayerPlaybackSourceRepository，调用方无需知道 source 来自 mock 还是远程。
class RemotePlayerPlaybackSourceRepository
    implements PlayerPlaybackSourceRepository {
  const RemotePlayerPlaybackSourceRepository({
    required PlaybackSourceRemoteDataSource remoteDataSource,
    required PlayerPlaybackPreloadManager preloadManager,
    Map<String, String>? httpHeaders,
    HlsProxyPlaybackSourceResolver? proxyResolver,
    PlaybackSourceMapper mapper = const PlaybackSourceMapper(),
  }) : _remoteDataSource = remoteDataSource,
       _preloadManager = preloadManager,
       _httpHeaders = httpHeaders,
       _proxyResolver = proxyResolver,
       _mapper = mapper;

  final PlaybackSourceRemoteDataSource _remoteDataSource;
  final PlayerPlaybackPreloadManager _preloadManager;
  final Map<String, String>? _httpHeaders;
  final PlaybackSourceMapper _mapper;
  final HlsProxyPlaybackSourceResolver? _proxyResolver;

  @override
  Future<PlaybackSource> resolve(PlayerFeedItem item) async {
    // 直接使用 episode.videoSource（来自首页 API 的 source_url），无需调用 playback-source API
    final remoteUrl = item.episode.videoSource;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      final dto = await _remoteDataSource.getPlaybackSource(
        episodeId: item.episode.id,
      );
      return _applyProxy(
        _mapper.mapSource(
          dto,
          item: item,
          status: PlaybackSourceStatus.resolved,
        ),
        item: item,
      );
    }

    return _applyProxy(
      PlaybackSource(
        itemId: item.id,
        remoteUrl: remoteUrl,
        playableSource: remoteUrl,
        cacheKey: _cacheKey(item),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        codecHint: 'hls',
        status: PlaybackSourceStatus.resolved,
        httpHeaders: _httpHeaders,
      ),
      item: item,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(
    PlayerFeedItem item, {
    Duration? preferredPosition,
  }) async {
    // 直接使用 episode.videoSource，无需调用 playback-source API
    final remoteUrl = item.episode.videoSource;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      final dto = await _remoteDataSource.getPlaybackSource(
        episodeId: item.episode.id,
      );
      final source = await _applyProxy(
        _mapper.mapSource(
          dto,
          item: item,
          status: PlaybackSourceStatus.preloaded,
        ),
        item: item,
      );
      return _preloadKnownSource(
        item,
        source,
        preferredPosition: preferredPosition,
      );
    }

    // 已解锁 source_url 的服务端契约是 HLS m3u8。入口可以是通用
    // `/api/video/source`，不以 URL 后缀判断；未来支持非 HLS 时应由后端下发
    // stream_format，再在这里按格式决定是否预热。
    return _preloadKnownSource(
      item,
      PlaybackSource(
        itemId: item.id,
        remoteUrl: remoteUrl,
        playableSource: remoteUrl,
        cacheKey: _cacheKey(item),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        codecHint: 'hls',
        status: PlaybackSourceStatus.preloaded,
        httpHeaders: _httpHeaders,
      ),
      preferredPosition: preferredPosition,
    );
  }

  Future<PlaybackPreloadState> _preloadKnownSource(
    PlayerFeedItem item,
    PlaybackSource source, {
    Duration? preferredPosition,
  }) async {
    return _preloadManager.preload(
      item: item,
      source: source,
      preferredPosition: preferredPosition,
    );
  }

  Future<PlaybackSource> _applyProxy(
    PlaybackSource source, {
    required PlayerFeedItem item,
  }) async {
    final playableSource =
        await _proxyResolver?.resolvePlayableSource(
          source.remoteUrl,
          owner: item.mode == PlayerFeedMode.forYou
              ? HlsTrafficOwner.forYou
              : HlsTrafficOwner.playback,
        ) ??
        source.remoteUrl;
    return PlaybackSource(
      itemId: source.itemId,
      remoteUrl: source.remoteUrl,
      playableSource: playableSource,
      cacheKey: source.cacheKey,
      expiresAt: source.expiresAt,
      codecHint: source.codecHint,
      status: source.status,
      httpHeaders: source.httpHeaders ?? _httpHeaders,
    );
  }

  String _cacheKey(PlayerFeedItem item) {
    return 'player:${item.content.id}:${item.episode.id}';
  }
}
