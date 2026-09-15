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
  Future<PlaybackSource> resolve(
    PlayerFeedItem item, {
    int? maxVideoHeight,
  }) async {
    final remoteUrl = item.episode.videoSource;
    if (!_isDirectPlayableSource(remoteUrl)) {
      // Feed 的 source_url 只是 source hint。线上偶尔会下发 CDN 根地址；
      // 它不是媒体清单，直接交给 native player 会表现为 playing 后无首帧。
      // 这时回退到带签名/有效期的 playback-source 解析接口。
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
        maxVideoHeight: maxVideoHeight,
      );
    }
    final playableRemoteUrl = remoteUrl!;

    return _applyProxy(
      PlaybackSource(
        itemId: item.id,
        remoteUrl: playableRemoteUrl,
        playableSource: playableRemoteUrl,
        cacheKey: _cacheKey(item),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        codecHint: 'hls',
        status: PlaybackSourceStatus.resolved,
        httpHeaders: _httpHeaders,
      ),
      item: item,
      maxVideoHeight: maxVideoHeight,
    );
  }

  @override
  Future<PlaybackPreloadState> preload(
    PlayerFeedItem item, {
    Duration? preferredPosition,
    int? maxVideoHeight,
  }) async {
    final remoteUrl = item.episode.videoSource;
    if (!_isDirectPlayableSource(remoteUrl)) {
      final dto = await _remoteDataSource.getPlaybackSource(
        episodeId: item.episode.id,
      );
      final source = _mapper.mapSource(
        dto,
        item: item,
        status: PlaybackSourceStatus.preloaded,
      );
      return _preloadKnownSource(
        item,
        source,
        preferredPosition: preferredPosition,
        maxVideoHeight: maxVideoHeight,
      );
    }
    final playableRemoteUrl = remoteUrl!;

    // 已解锁 source_url 的服务端契约是 HLS m3u8。入口可以是通用
    // `/api/video/source`，不以 URL 后缀判断；未来支持非 HLS 时应由后端下发
    // stream_format，再在这里按格式决定是否预热。
    return _preloadKnownSource(
      item,
      PlaybackSource(
        itemId: item.id,
        remoteUrl: playableRemoteUrl,
        playableSource: playableRemoteUrl,
        cacheKey: _cacheKey(item),
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
        codecHint: 'hls',
        status: PlaybackSourceStatus.preloaded,
        httpHeaders: _httpHeaders,
      ),
      preferredPosition: preferredPosition,
      maxVideoHeight: maxVideoHeight,
    );
  }

  Future<PlaybackPreloadState> _preloadKnownSource(
    PlayerFeedItem item,
    PlaybackSource source, {
    Duration? preferredPosition,
    int? maxVideoHeight,
  }) async {
    final resolved = await _applyProxy(
      source,
      item: item,
      maxVideoHeight: maxVideoHeight,
    );
    return _preloadManager.preload(
      item: item,
      source: resolved,
      preferredPosition: preferredPosition,
    );
  }

  Future<PlaybackSource> _applyProxy(
    PlaybackSource source, {
    required PlayerFeedItem item,
    int? maxVideoHeight,
  }) async {
    final playableSource =
        await _proxyResolver?.resolvePlayableSource(
          source.remoteUrl,
          owner: item.mode == PlayerFeedMode.forYou
              ? HlsTrafficOwner.forYou
              : HlsTrafficOwner.playback,
          maxVideoHeight: maxVideoHeight,
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

  /// The feed may provide a CDN root as a hint. Keep extensionless, real
  /// media endpoints supported, but never treat a bare origin/path root as a
  /// playable stream.
  bool _isDirectPlayableSource(String? source) {
    if (source == null || source.trim().isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(source);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    final path = uri.path;
    return path.isNotEmpty && path != '/';
  }
}
