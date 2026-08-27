import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';
import 'hls_disk_cache_store.dart';
import 'hls_local_proxy_server.dart';
import 'hls_network_request_coordinator.dart';

/// HLS 预热结果。
///
/// 这个结果用于诊断和状态记录，不用于证明视频一定可播放；播放仍要经过 media open。
class HlsPlaylistPrefetchResult {
  const HlsPlaylistPrefetchResult({
    required this.url,
    required this.contentLength,
    required this.isMasterPlaylist,
    required this.fetchedAt,
    required this.mediaPlaylistUrl,
    required this.segmentUrls,
    required this.segmentBytesPreheated,
    required this.diagnostics,
  });

  /// 原始预热 URL。
  final String url;

  /// playlist 响应累计字节数。
  ///
  /// 不包含 segment 预热字节，segment 另见 `segmentBytesPreheated`。
  final int contentLength;

  /// 是否为 master playlist。
  ///
  /// master playlist 会再选择一个 variant media playlist 预热。
  final bool isMasterPlaylist;

  /// 预热完成时间。
  final DateTime fetchedAt;

  /// 实际预热的 media playlist URL。
  ///
  /// master playlist 下可能与原始 URL 不同。
  final String mediaPlaylistUrl;

  /// 已预热的 segment URL 列表。
  ///
  /// 受 maxSegments 和 maxPreheatBytes 限制，不代表完整视频已缓存。
  final List<String> segmentUrls;

  /// 已预热 segment 的字节数。
  final int segmentBytesPreheated;

  /// 预热诊断信息。
  ///
  /// 用于 timing/report，不作为业务逻辑判断。
  final List<String> diagnostics;
}

class HlsPlaylistPrefetchException implements Exception {
  const HlsPlaylistPrefetchException(this.message);

  /// 预热失败原因。
  final String message;

  @override
  String toString() => 'HlsPlaylistPrefetchException: $message';
}

class HlsPlaylistPreloadCancelledException implements Exception {
  const HlsPlaylistPreloadCancelledException();

  @override
  String toString() => 'HlsPlaylistPreloadCancelledException';
}

class HlsPlaylistHttpResponse {
  const HlsPlaylistHttpResponse({
    required this.statusCode,
    required this.body,
    this.contentLength,
    this.bytes,
  });

  /// HTTP 状态码。
  final int statusCode;

  /// 响应文本。
  ///
  /// 只用于 playlist 解析；segment 预热在这里也按字节长度统计，不解析媒体内容。
  final String body;

  /// 响应字节长度。
  ///
  /// 如果 HTTP client 没提供，则按 UTF-8 文本估算。
  final int? contentLength;
  final List<int>? bytes;

  int get byteLength => contentLength ?? utf8.encode(body).length;
  List<int> get rawBytes => bytes ?? utf8.encode(body);
}

abstract interface class HlsPlaylistHttpClient {
  Future<HlsPlaylistHttpResponse> get(Uri uri, {required Duration timeout});

  void releasePending();
}

class DartIoHlsPlaylistHttpClient
    implements HlsPlaylistHttpClient, HlsNetworkStreamingHttpClient {
  DartIoHlsPlaylistHttpClient({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;
  final _pendingRequests = <HttpClientRequest>{};

  @override
  Future<HlsPlaylistHttpResponse> get(
    Uri uri, {
    required Duration timeout,
  }) async {
    final request = await _client.getUrl(uri).timeout(timeout);
    _pendingRequests.add(request);
    try {
      final response = await request.close().timeout(timeout);
      final bytes = await response
          .fold<List<int>>(
            <int>[],
            (previous, element) => previous..addAll(element),
          )
          .timeout(timeout);
      return HlsPlaylistHttpResponse(
        statusCode: response.statusCode,
        body: utf8.decode(bytes, allowMalformed: true),
        contentLength: bytes.length,
        bytes: bytes,
      );
    } finally {
      _pendingRequests.remove(request);
    }
  }

  @override
  Future<HlsNetworkStreamResponse> open(
    Uri uri, {
    required Duration timeout,
  }) async {
    final request = await _client.getUrl(uri).timeout(timeout);
    _pendingRequests.add(request);
    final response = await request.close().timeout(timeout);
    Stream<List<int>> chunks() async* {
      try {
        await for (final chunk in response) {
          yield List<int>.from(chunk);
        }
      } finally {
        _pendingRequests.remove(request);
      }
    }

    return HlsNetworkStreamResponse(
      statusCode: response.statusCode,
      chunks: chunks(),
      contentType: response.headers.contentType?.mimeType,
    );
  }

  @override
  void releasePending() {
    for (final request in List<HttpClientRequest>.from(_pendingRequests)) {
      request.abort();
    }
    _pendingRequests.clear();
  }
}

/// 轻量 HLS HTTP 预热器，只预取 playlist 和有限首段 segment。
///
/// 它不创建 media session，也不保证后续播放一定走本地缓存；目标只是让 CDN/DNS/TLS
/// 和首段数据提前热起来。不要把它扩展成通用下载器，否则会和当前播放抢带宽，
/// 还会引入离线缓存、过期和版权策略问题。
class HlsPlaylistPreloader {
  HlsPlaylistPreloader({
    HlsPlaylistHttpClient? client,
    this.timeout = const Duration(seconds: 4),
    this.sharedRequestTimeout = const Duration(seconds: 12),
    this.maxSegments = 2,
    this.maxPreheatBytes = 2 * 1024 * 1024,
    HlsLocalCacheStore? cacheStore,
    HlsDiskCacheStore? diskCacheStore,
    HlsNetworkRequestCoordinator? networkCoordinator,
  }) : _client = client ?? DartIoHlsPlaylistHttpClient(),
       _cacheStore = cacheStore,
       _diskCacheStore = diskCacheStore,
       _networkCoordinator =
           networkCoordinator ?? HlsNetworkRequestCoordinator();

  /// HLS HTTP client。
  ///
  /// 通过接口注入，方便测试取消、超时和失败，不直接绑定 dart:io。
  final HlsPlaylistHttpClient _client;
  final HlsLocalCacheStore? _cacheStore;
  final HlsDiskCacheStore? _diskCacheStore;
  final HlsNetworkRequestCoordinator _networkCoordinator;

  /// 单次 playlist/segment 预热的等待预算。
  ///
  /// 到期后预热会尽快让出状态；已开始的共享请求仍可由真实播放复用。
  final Duration timeout;

  /// 单个共享网络请求的最长寿命。
  ///
  /// 真实播放可能在预热开始后才加入同一请求，不能继承较短的预热预算，否则慢
  /// 首段会在播放接管时被切断并触发一次重复回源。
  final Duration sharedRequestTimeout;

  /// 最多预热的 segment 数量。
  ///
  /// 控制请求数量，避免信息流快速滑动时过度预取。
  final int maxSegments;

  /// segment 预热字节预算。
  ///
  /// 控制流量上限，避免首段过大时抢占当前播放带宽。
  final int maxPreheatBytes;
  int _generation = 0;
  HlsRequestPriority _activePriority = HlsRequestPriority.preload;

  Future<HlsPlaylistPrefetchResult> prefetch(
    String sourceUrl, {
    Duration? preferredPosition,
  }) {
    _activePriority = HlsRequestPriority.preload;
    final generation = _generation;
    return _prefetch(
      sourceUrl,
      generation: generation,
      preferredPosition: preferredPosition,
    ).timeout(
      timeout,
      onTimeout: () {
        // 仅让本次预热停止后续步骤；不可 abort singleflight 中的 HTTP，因为
        // 真实播放器可能已经加入并正在等待同一 playlist/segment。
        if (generation == _generation) {
          _generation += 1;
        }
        throw TimeoutException(
          'HLS preload exceeded its wait budget.',
          timeout,
        );
      },
    );
  }

  /// 普通播放器已接管同一 source 时，把尚未发出的关键段请求提升为 playback。
  ///
  /// 已经在飞行的请求不能重启，否则反而丢掉已下载字节；它们仍可通过 singleflight
  /// 被代理加入。该提升只影响随后解析出的初始化段/目标段请求。
  void promotePendingToPlayback() {
    _activePriority = HlsRequestPriority.playback;
  }

  Future<HlsPlaylistPrefetchResult> _prefetch(
    String sourceUrl, {
    required int generation,
    Duration? preferredPosition,
  }) async {
    final uri = _parseHttpUri(sourceUrl);
    final diagnostics = <String>[];

    final playlistStartedAt = DateTime.now();
    diagnostics.add('hls master playlist fetch start');
    final response = await _getOrThrow(uri, generation: generation);
    _cacheStore?.write(uri.toString(), response.rawBytes);
    _writeDisk(uri, response.rawBytes, contentType: _playlistContentType);
    diagnostics.add(
      'hls master playlist fetch end ${_elapsedMs(playlistStartedAt)}ms',
    );

    final isMasterPlaylist = response.body.contains('#EXT-X-STREAM-INF');
    var mediaPlaylistUri = uri;
    var mediaPlaylistBody = response.body;
    var contentLength = response.byteLength;

    if (isMasterPlaylist) {
      _logMasterPlaylistVariants(uri, response.body);
      final variantUri = _selectVariantUri(uri, response.body);
      if (variantUri != null) {
        final mediaStartedAt = DateTime.now();
        diagnostics.add('hls media playlist fetch start');
        final mediaResponse = await _getOrThrow(
          variantUri,
          generation: generation,
        );
        _cacheStore?.write(variantUri.toString(), mediaResponse.rawBytes);
        _writeDisk(
          variantUri,
          mediaResponse.rawBytes,
          contentType: _playlistContentType,
        );
        diagnostics.add(
          'hls media playlist fetch end ${_elapsedMs(mediaStartedAt)}ms',
        );
        mediaPlaylistUri = variantUri;
        mediaPlaylistBody = mediaResponse.body;
        contentLength += mediaResponse.byteLength;
      } else {
        diagnostics.add('hls media playlist missing variant');
      }
    }

    final resumeTargetIndex = _resumeTargetSegmentIndex(
      mediaPlaylistBody,
      preferredPosition: preferredPosition,
    );
    final segmentUris = _segmentUrisAroundPosition(
      mediaPlaylistUri,
      mediaPlaylistBody,
      resumeTargetIndex: resumeTargetIndex,
    ).take(maxSegments).toList(growable: false);
    final preheatedSegments = <Uri>[];
    var segmentBytesPreheated = 0;

    // 续播有两个同等关键的冷点：播放器初始化所需的首段，以及目标时间附近的段。
    // 原来顺序下载会让目标段必须等首段完成；当用户已经有 55/74 秒进度时，这正好
    // 放大首播等待。仅在续播且实际有两个候选时并行这两个请求；非续播仍保持顺序和
    // 严格字节预算，避免信息流场景多段抢占正在播放的资源。
    final parallelResumeSegments =
        resumeTargetIndex != null &&
        resumeTargetIndex > 0 &&
        segmentUris.length > 1;
    if (parallelResumeSegments) {
      diagnostics.add('resume first/target segment preheat parallel start');
      final startedAt = DateTime.now();
      final responses = await Future.wait(
        segmentUris
            .take(2)
            .map(
              (segmentUri) => _getOrThrow(segmentUri, generation: generation),
            ),
      );
      for (var index = 0; index < responses.length; index += 1) {
        final segmentUri = segmentUris[index];
        final segmentResponse = responses[index];
        _cacheStore?.write(segmentUri.toString(), segmentResponse.rawBytes);
        _writeDisk(
          segmentUri,
          segmentResponse.rawBytes,
          contentType: _segmentContentType(segmentUri),
        );
        final segmentBytes = segmentResponse.byteLength;
        segmentBytesPreheated += segmentBytes;
        preheatedSegments.add(segmentUri);
        diagnostics.add(
          'hls segment ${index + 1} parallel preheat end '
          '${_elapsedMs(startedAt)}ms bytes=$segmentBytes',
        );
      }
      if (segmentBytesPreheated >= maxPreheatBytes) {
        diagnostics.add('segment preheat max bytes reached');
      }
    } else {
      // 只预热少量首段并受字节预算限制。短剧滑动场景下，用户可能马上离开当前 item，
      // 过度预取会浪费流量并影响真正播放中的 source。
      for (var index = 0; index < segmentUris.length; index += 1) {
        if (segmentBytesPreheated >= maxPreheatBytes) {
          diagnostics.add('segment preheat max bytes reached');
          break;
        }
        final segmentUri = segmentUris[index];
        final segmentStartedAt = DateTime.now();
        diagnostics.add('hls segment ${index + 1} preheat start');
        final segmentResponse = await _getOrThrow(
          segmentUri,
          generation: generation,
        );
        _cacheStore?.write(segmentUri.toString(), segmentResponse.rawBytes);
        _writeDisk(
          segmentUri,
          segmentResponse.rawBytes,
          contentType: _segmentContentType(segmentUri),
        );
        final segmentBytes = segmentResponse.byteLength;
        segmentBytesPreheated += segmentBytes;
        preheatedSegments.add(segmentUri);
        diagnostics.add(
          'hls segment ${index + 1} preheat end '
          '${_elapsedMs(segmentStartedAt)}ms bytes=$segmentBytes',
        );
        if (segmentBytesPreheated >= maxPreheatBytes) {
          diagnostics.add('segment preheat max bytes reached');
          break;
        }
      }
    }
    diagnostics.add('segment preheat bytes=$segmentBytesPreheated');

    return HlsPlaylistPrefetchResult(
      url: sourceUrl,
      contentLength: contentLength,
      isMasterPlaylist: isMasterPlaylist,
      fetchedAt: DateTime.now(),
      mediaPlaylistUrl: mediaPlaylistUri.toString(),
      segmentUrls: preheatedSegments
          .map((segmentUri) => segmentUri.toString())
          .toList(growable: false),
      segmentBytesPreheated: segmentBytesPreheated,
      diagnostics: diagnostics,
    );
  }

  void releasePending() {
    // generation 用来让已发出的异步请求在返回后自我失效；HTTP abort 只是尽力而为。
    _generation += 1;
    // 不 abort 底层 HTTP：真实播放器可能已加入同一 playlist/segment 的单飞请求。
    // generation 会让已取消预热的结果不再写入其自身状态，下载仍可被播放代理复用。
  }

  Uri _parseHttpUri(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException('Invalid HLS playlist URL.', sourceUrl);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Unsupported HLS playlist URL scheme.', sourceUrl);
    }
    return uri;
  }

  Future<HlsPlaylistHttpResponse> _getOrThrow(
    Uri uri, {
    required int generation,
  }) async {
    final streamingClient = _client;
    final HlsNetworkResponse shared;
    if (streamingClient is HlsNetworkStreamingHttpClient) {
      final client = streamingClient as HlsNetworkStreamingHttpClient;
      shared = await _networkCoordinator
          .streamFetch(
            uri,
            priority: _activePriority,
            open: () => client.open(uri, timeout: sharedRequestTimeout),
          )
          .completed;
    } else {
      shared = await _networkCoordinator.fetch(
        uri,
        priority: _activePriority,
        request: () async {
          final response = await _client.get(
            uri,
            timeout: sharedRequestTimeout,
          );
          return HlsNetworkResponse(
            statusCode: response.statusCode,
            bytes: response.rawBytes,
          );
        },
      );
    }
    final response = HlsPlaylistHttpResponse(
      statusCode: shared.statusCode,
      body: utf8.decode(shared.bytes, allowMalformed: true),
      contentLength: shared.bytes.length,
      bytes: shared.bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HlsPlaylistPrefetchException(
        'HLS request failed with HTTP ${response.statusCode}: $uri',
      );
    }
    // 点击接管会使 startup generation 失效，但此前已经开始的 playlist 请求无需
    // 浪费：先把成功字节写入共享缓存，随后真实播放器可直接命中。generation 检查
    // 保留在写缓存之后，确保取消的预热不会继续解析 playlist 或拉取任何分片。
    _cacheStore?.write(uri.toString(), response.rawBytes);
    _writeDisk(uri, response.rawBytes, contentType: _playlistContentType);
    if (generation != _generation) {
      throw const HlsPlaylistPreloadCancelledException();
    }
    return response;
  }

  Uri? _selectVariantUri(Uri masterUri, String playlistBody) {
    final variants = _parseVariants(masterUri, playlistBody);
    if (variants.isEmpty) {
      return null;
    }
    variants.sort((left, right) {
      final leftBandwidth = left.bandwidth ?? 1 << 62;
      final rightBandwidth = right.bandwidth ?? 1 << 62;
      return leftBandwidth.compareTo(rightBandwidth);
    });
    return variants.first.uri;
  }

  /// 输出 master playlist 的真实清晰度，供接入手动清晰度选择前核验 CDN 配置。
  ///
  /// 仅记录路径和 HLS 元数据，不记录 query 中可能存在的签名参数。
  void _logMasterPlaylistVariants(Uri masterUri, String playlistBody) {
    final variants = _parseVariants(masterUri, playlistBody);
    if (variants.isEmpty) {
      developer.log(
        'master=${_safePlaylistUri(masterUri)} variants=none',
        name: 'HlsQuality',
      );
      return;
    }
    final details = variants
        .map(
          (variant) =>
              'resolution=${variant.resolution ?? 'unknown'} '
              'bandwidth=${variant.bandwidth ?? 'unknown'} '
              'playlist=${_safePlaylistUri(variant.uri)}',
        )
        .join('; ');
    developer.log(
      'master=${_safePlaylistUri(masterUri)} variants=${variants.length}: '
      '$details',
      name: 'HlsQuality',
    );
  }

  List<_HlsVariant> _parseVariants(Uri masterUri, String playlistBody) {
    final lines = const LineSplitter()
        .convert(playlistBody)
        .map((line) => line.trim())
        .toList(growable: false);
    final variants = <_HlsVariant>[];
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      if (!line.startsWith('#EXT-X-STREAM-INF')) {
        continue;
      }
      final bandwidth = _parseBandwidth(line);
      for (var next = index + 1; next < lines.length; next += 1) {
        final uriLine = lines[next];
        if (uriLine.isEmpty) {
          continue;
        }
        if (uriLine.startsWith('#')) {
          break;
        }
        variants.add(
          _HlsVariant(
            uri: masterUri.resolve(uriLine),
            bandwidth: bandwidth,
            resolution: _parseResolution(line),
          ),
        );
        break;
      }
    }
    return variants;
  }

  int? _parseBandwidth(String streamInfLine) {
    final match = RegExp(r'BANDWIDTH=(\d+)').firstMatch(streamInfLine);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  String? _parseResolution(String streamInfLine) {
    final match = RegExp(
      r'RESOLUTION=(\d+x\d+)',
      caseSensitive: false,
    ).firstMatch(streamInfLine);
    return match?.group(1);
  }

  String _safePlaylistUri(Uri uri) => uri.replace(query: '').toString();

  List<Uri> _parseSegmentUris(Uri mediaPlaylistUri, String playlistBody) {
    return const LineSplitter()
        .convert(playlistBody)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map(mediaPlaylistUri.resolve)
        .toList(growable: false);
  }

  List<Uri> _segmentUrisAroundPosition(
    Uri mediaPlaylistUri,
    String playlistBody, {
    int? resumeTargetIndex,
  }) {
    final segments = _parseSegmentUris(mediaPlaylistUri, playlistBody);
    if (resumeTargetIndex == null || resumeTargetIndex <= 0) {
      return segments;
    }
    // MediaKit 即使 open(start: savedPosition) 也通常需要先读取第一个分片来建
    // demux/decoder；只预热 target/next 会让续播仍卡在 00001、00002 的首次回源。
    // 因此续播优先级为：初始化首段 -> 目标段 -> 目标后一段。默认最多两段，正好
    // 覆盖首段和目标段；若配置允许更多段，再顺序补目标后的连续分片。
    return [segments.first, ...segments.skip(resumeTargetIndex)];
  }

  /// 返回续播位置落入的分片下标；位置仍在首分片时返回 0。
  ///
  /// 这时首分片本身就是目标，不能把第二段误当成“目标段”并行下载，否则会让
  /// 2 秒续播这类情况白白多抢一条分片带宽。
  int? _resumeTargetSegmentIndex(
    String playlistBody, {
    Duration? preferredPosition,
  }) {
    if (preferredPosition == null || preferredPosition <= Duration.zero) {
      return null;
    }
    final durations = _segmentDurations(playlistBody);
    if (durations.isEmpty) return null;
    var accumulated = Duration.zero;
    for (var index = 0; index < durations.length; index += 1) {
      accumulated += durations[index];
      if (preferredPosition < accumulated) return index;
    }
    return durations.length - 1;
  }

  List<Duration> _segmentDurations(String playlistBody) {
    final durations = <Duration>[];
    for (final line in const LineSplitter().convert(playlistBody)) {
      final match = RegExp(r'^#EXTINF:([0-9.]+)').firstMatch(line.trim());
      if (match == null) continue;
      final seconds = double.tryParse(match.group(1)!);
      if (seconds != null && seconds >= 0) {
        durations.add(Duration(milliseconds: (seconds * 1000).round()));
      }
    }
    return durations;
  }

  int _elapsedMs(DateTime startedAt) {
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  void _writeDisk(Uri uri, List<int> bytes, {required String contentType}) {
    final store = _diskCacheStore;
    if (store == null) return;
    // 落盘不占用预热完成或首帧关键路径；播放仍会从内存、磁盘或远端回退。
    unawaited(
      store.write(
        HlsDiskCacheStore.keyForUri(uri),
        bytes,
        contentType: contentType,
      ),
    );
  }

  static const _playlistContentType = 'application/vnd.apple.mpegurl';

  String _segmentContentType(Uri uri) {
    final extension = uri.pathSegments.lastOrNull
        ?.split('.')
        .last
        .toLowerCase();
    return switch (extension) {
      'm4s' || 'mp4' => 'video/mp4',
      'aac' => 'audio/aac',
      _ => 'video/mp2t',
    };
  }
}

class _HlsVariant {
  const _HlsVariant({
    required this.uri,
    required this.bandwidth,
    required this.resolution,
  });

  final Uri uri;
  final int? bandwidth;
  final String? resolution;
}

class HlsPlayerPlaybackPreloadManager implements PlayerPlaybackPreloadManager {
  HlsPlayerPlaybackPreloadManager({required HlsPlaylistPreloader preloader})
    : _preloader = preloader;

  final HlsPlaylistPreloader _preloader;

  @override
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
    Duration? preferredPosition,
  }) async {
    final startedAt = DateTime.now();
    try {
      final result = await _preloader.prefetch(
        source.playableSource,
        preferredPosition: preferredPosition,
      );
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: source.playableSource,
        status: PlaybackPreloadStatus.success,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        details: result.diagnostics.join(' | '),
      );
    } on HlsPlaylistPreloadCancelledException {
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: source.playableSource,
        status: PlaybackPreloadStatus.cancelled,
        startedAt: startedAt,
        completedAt: DateTime.now(),
      );
    } catch (error) {
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: source.playableSource,
        status: PlaybackPreloadStatus.failed,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        error: error,
      );
    }
  }

  @override
  Future<void> releasePending() async {
    _preloader.releasePending();
  }
}
