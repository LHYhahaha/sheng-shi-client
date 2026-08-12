import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'hls_disk_cache_store.dart';

/// 本地 HLS proxy 的缓存配置。
///
/// 当前已解锁 source_url 的服务端契约是 HLS m3u8，即使入口是通用
/// `/api/video/source` 地址，最终响应也必须是 playlist。若未来允许 MP4 等其他
/// 格式，必须由后端同时下发 stream_format，再按单条 source 决定是否启用代理。
class HlsLocalProxyConfig {
  const HlsLocalProxyConfig({
    this.enabled = true,
    this.timeout = const Duration(seconds: 4),
  });

  /// 是否启用本地代理 spike。
  ///
  /// 默认开启；可通过编译期开关在异常源或紧急回退时关闭。
  final bool enabled;

  /// 代理向远端请求 playlist/segment 的超时。
  final Duration timeout;
}

/// 本地 HLS proxy 的远端响应包装。
class HlsLocalProxyResponse {
  const HlsLocalProxyResponse({
    required this.statusCode,
    required this.bytes,
    this.contentType,
  });

  /// 远端 HTTP 状态码。
  final int statusCode;

  /// 响应字节。
  ///
  /// playlist 和 segment 都以字节保存，playlist 需要时再按文本解码。
  final List<int> bytes;

  /// 响应 content type。
  ///
  /// segment 回写给播放器时尽量保留，避免播放器 MIME 判断异常。
  final String? contentType;

  String get body => utf8.decode(bytes, allowMalformed: true);
}

abstract interface class HlsLocalProxyHttpClient {
  /// 拉取远端 playlist 或 segment。
  ///
  /// 这是 proxy spike 的底层 HTTP 能力，不承担业务鉴权刷新。真实 signed URL 过期时，
  /// 应回到播放源接口刷新，而不是在这里私自重试旧 URL。
  Future<HlsLocalProxyResponse> get(Uri uri, {required Duration timeout});

  /// 释放仍在进行中的远端请求。
  ///
  /// 页面隐藏、播放器 dispose 或 proxy stop 时必须调用，避免本地代理继续下载 segment。
  void releasePending();
}

class DartIoHlsLocalProxyHttpClient implements HlsLocalProxyHttpClient {
  DartIoHlsLocalProxyHttpClient({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;
  final _pendingRequests = <HttpClientRequest>{};

  @override
  Future<HlsLocalProxyResponse> get(
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
      return HlsLocalProxyResponse(
        statusCode: response.statusCode,
        bytes: bytes,
        contentType: response.headers.contentType?.mimeType,
      );
    } finally {
      _pendingRequests.remove(request);
    }
  }

  @override
  void releasePending() {
    for (final request in List<HttpClientRequest>.from(_pendingRequests)) {
      request.abort();
    }
    _pendingRequests.clear();
  }
}

/// 本地代理的内存 segment 缓存。
///
/// 只在 proxy server 生命周期内有效，不是持久缓存。stop 时必须清空，避免 spike 数据
/// 跨会话复用。
class HlsLocalCacheStore {
  HlsLocalCacheStore({this.maxBytes = 24 * 1024 * 1024});

  final int maxBytes;
  final _bytesByUrl = <String, List<int>>{};
  final _accessOrder = <String>[];
  var _totalBytes = 0;

  bool contains(String url) => _bytesByUrl.containsKey(url);

  List<int>? read(String url) {
    final bytes = _bytesByUrl[url];
    if (bytes != null) {
      _accessOrder
        ..remove(url)
        ..add(url);
    }
    return bytes;
  }

  void write(String url, List<int> bytes) {
    final frozen = List<int>.unmodifiable(bytes);
    final previous = _bytesByUrl[url];
    if (previous != null) {
      _totalBytes -= previous.length;
    }
    _bytesByUrl[url] = frozen;
    _totalBytes += frozen.length;
    _accessOrder
      ..remove(url)
      ..add(url);
    while (_totalBytes > maxBytes && _accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      final removed = _bytesByUrl.remove(oldest);
      if (removed != null) _totalBytes -= removed.length;
    }
  }

  void clear() {
    _bytesByUrl.clear();
    _accessOrder.clear();
    _totalBytes = 0;
  }
}

/// 本地 HLS proxy，用于 HLS playlist 重写和分片缓存。
///
/// 调用方必须先确认资源格式为 HLS；它不能作为通用视频地址的格式探测器。
class HlsLocalProxyServer {
  HlsLocalProxyServer({
    HlsLocalProxyHttpClient? client,
    HlsLocalCacheStore? cacheStore,
    HlsDiskCacheStore? diskCacheStore,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? DartIoHlsLocalProxyHttpClient(),
       _cacheStore = cacheStore ?? HlsLocalCacheStore(),
       _diskCacheStore = diskCacheStore ?? HlsDiskCacheStore();

  /// 代理向远端拉取 playlist/segment 的 HTTP client。
  final HlsLocalProxyHttpClient _client;

  /// 内存缓存。
  ///
  /// 只缓存 segment bytes，不缓存业务授权状态。
  final HlsLocalCacheStore _cacheStore;
  final HlsDiskCacheStore _diskCacheStore;

  /// 远端请求超时。
  final Duration timeout;
  HttpServer? _server;
  var _generation = 0;

  bool get isRunning => _server != null;

  Future<String> proxyUrlFor(String remoteUrl) async {
    final remoteUri = _parseRemoteUri(remoteUrl);
    final server = await _ensureStarted();
    final proxyUri = Uri(
      scheme: 'http',
      // Android network security config explicitly permits localhost cleartext.
      // 使用 127.0.0.1 会绕过该 domain rule，在部分系统上被直接拦截。
      host: 'localhost',
      port: server.port,
      path: '/playlist.m3u8',
      queryParameters: {'url': remoteUri.toString()},
    );
    _log('proxy source generated source=$remoteUrl proxy=$proxyUri');
    return proxyUri.toString();
  }

  Future<void> stop() async {
    // stop 只清一级内存缓存；App 私有磁盘缓存需要跨播放器页面与 App 重启复用。
    _generation += 1;
    _client.releasePending();
    final server = _server;
    _server = null;
    await server?.close(force: true);
    _cacheStore.clear();
    _log('proxy server stop');
  }

  Future<HttpServer> _ensureStarted() async {
    final existing = _server;
    if (existing != null) {
      return existing;
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _log('proxy server start port=${server.port}');
    unawaited(_serve(server));
    return server;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final remoteUrl = request.uri.queryParameters['url'];
      if (remoteUrl == null || remoteUrl.isEmpty) {
        await _sendText(request, HttpStatus.badRequest, 'Missing url');
        return;
      }
      final remoteUri = _parseRemoteUri(remoteUrl);
      if (request.uri.path.endsWith('.m3u8')) {
        await _proxyPlaylist(request, remoteUri);
      } else {
        await _proxySegment(request, remoteUri);
      }
    } catch (error) {
      _log('fallback remote source error=$error');
      try {
        await _sendText(request, HttpStatus.badGateway, error.toString());
      } catch (_) {
        await request.response.close();
      }
    }
  }

  Future<void> _proxyPlaylist(HttpRequest request, Uri remoteUri) async {
    final startedAt = DateTime.now();
    final cacheKey = remoteUri.toString();
    final cached = _cacheStore.read(cacheKey);
    HlsLocalProxyResponse response;
    if (cached != null) {
      response = HlsLocalProxyResponse(
        statusCode: HttpStatus.ok,
        bytes: cached,
        contentType: 'application/vnd.apple.mpegurl',
      );
    } else {
      final disk = await _diskCacheStore.read(_diskKey(remoteUri));
      if (disk != null) {
        response = HlsLocalProxyResponse(
          statusCode: HttpStatus.ok,
          bytes: disk.bytes,
          contentType: disk.contentType,
        );
        _cacheStore.write(cacheKey, response.bytes);
      } else {
        response = await _fetch(remoteUri);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await _sendText(
            request,
            HttpStatus.badGateway,
            'Playlist fetch failed: ${response.statusCode}',
          );
          return;
        }
        _cacheStore.write(cacheKey, response.bytes);
        await _diskCacheStore.write(
          _diskKey(remoteUri),
          response.bytes,
          contentType: response.contentType,
        );
      }
    }
    if (!response.body.trimLeft().startsWith('#EXTM3U')) {
      await request.response.redirect(
        remoteUri,
        status: HttpStatus.temporaryRedirect,
      );
      return;
    }
    // 只重写 playlist 中的媒体 URI，不改 HLS tag。这样方便观察代理链路，
    // 也避免客户端在 spike 阶段承担完整 HLS manifest 解析职责。
    final rewritten = rewritePlaylist(
      remoteUri,
      response.body,
      localBaseUri: _localBaseUri(request),
    );
    request.response.headers.contentType = ContentType(
      'application',
      'vnd.apple.mpegurl',
      charset: 'utf-8',
    );
    request.response.write(rewritten);
    await request.response.close();
    _log(
      'playlist proxy fetch ${cached == null ? 'miss' : 'hit'} source=$remoteUri '
      'elapsedMs=${_elapsedMs(startedAt)} bytes=${response.bytes.length}',
    );
  }

  Future<void> _proxySegment(HttpRequest request, Uri remoteUri) async {
    final cacheKey = remoteUri.toString();
    // segment 缓存只按完整 URL 命中，不做跨 token/跨清晰度合并，避免签名 URL 或
    // variant 切换时错用旧内容。
    final cachedBytes = _cacheStore.read(cacheKey);
    if (cachedBytes != null) {
      await _sendBytes(request, cachedBytes);
      _log(
        'segment proxy fetch hit source=$remoteUri bytes=${cachedBytes.length}',
      );
      return;
    }

    final disk = await _diskCacheStore.read(_diskKey(remoteUri));
    if (disk != null) {
      _cacheStore.write(cacheKey, disk.bytes);
      await _sendBytes(request, disk.bytes, contentType: disk.contentType);
      _log(
        'segment proxy disk hit source=$remoteUri bytes=${disk.bytes.length}',
      );
      return;
    }

    final generation = _generation;
    final startedAt = DateTime.now();
    final response = await _fetch(remoteUri);
    if (generation != _generation) {
      await _sendText(request, 499, 'Proxy request cancelled');
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _sendText(
        request,
        HttpStatus.badGateway,
        'Segment fetch failed: ${response.statusCode}',
      );
      return;
    }
    _cacheStore.write(cacheKey, response.bytes);
    await _diskCacheStore.write(
      _diskKey(remoteUri),
      response.bytes,
      contentType: response.contentType,
    );
    await _sendBytes(
      request,
      response.bytes,
      contentType: response.contentType,
    );
    _log(
      'segment proxy fetch miss source=$remoteUri '
      'elapsedMs=${_elapsedMs(startedAt)} bytes=${response.bytes.length}',
    );
  }

  Future<HlsLocalProxyResponse> _fetch(Uri uri) {
    return _client.get(uri, timeout: timeout).timeout(timeout);
  }

  Uri _localBaseUri(HttpRequest request) {
    final hostHeader = request.headers.value(HttpHeaders.hostHeader);
    final hostUri = hostHeader == null
        ? null
        : Uri.tryParse('http://$hostHeader');
    return Uri(
      scheme: 'http',
      host: hostUri?.host ?? InternetAddress.loopbackIPv4.address,
      port: hostUri?.port ?? request.connectionInfo?.localPort,
      path: '/',
    );
  }

  Uri _parseRemoteUri(String remoteUrl) {
    final uri = Uri.tryParse(remoteUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException('Invalid HLS proxy URL.', remoteUrl);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Unsupported HLS proxy scheme.', remoteUrl);
    }
    return uri;
  }

  String _diskKey(Uri uri) {
    final stableQuery = Map<String, String>.from(uri.queryParameters)
      ..remove('expires')
      ..remove('verify');
    return uri
        .replace(queryParameters: stableQuery.isEmpty ? null : stableQuery)
        .toString();
  }

  Future<void> _sendText(
    HttpRequest request,
    int statusCode,
    String message,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.text;
    request.response.write(message);
    await request.response.close();
  }

  Future<void> _sendBytes(
    HttpRequest request,
    List<int> bytes, {
    String? contentType,
  }) async {
    request.response.statusCode = HttpStatus.ok;
    if (contentType != null) {
      request.response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    }
    request.response.add(bytes);
    await request.response.close();
  }

  int _elapsedMs(DateTime startedAt) {
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  void _log(String message) {
    const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
    if (shouldPrint) {
      debugPrint(
        '${DateTime.now().toIso8601String()} session=hls-local-proxy $message',
      );
    }
  }
}

String rewritePlaylist(
  Uri playlistUri,
  String playlistBody, {
  required Uri localBaseUri,
}) {
  final lines = const LineSplitter().convert(playlistBody);
  final rewrittenLines = lines.map((line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return line;
    }
    if (trimmed.startsWith('#')) {
      return _rewriteTagUri(
        trimmed,
        playlistUri: playlistUri,
        localBaseUri: localBaseUri,
      );
    }
    final resolved = playlistUri.resolve(trimmed);
    final isPlaylist = resolved.path.toLowerCase().endsWith('.m3u8');
    final path = isPlaylist ? '/playlist.m3u8' : '/segment';
    return localBaseUri
        .replace(path: path, queryParameters: {'url': resolved.toString()})
        .toString();
  });
  return rewrittenLines.join('\n');
}

String _rewriteTagUri(
  String line, {
  required Uri playlistUri,
  required Uri localBaseUri,
}) {
  if (!line.startsWith('#EXT-X-KEY:') &&
      !line.startsWith('#EXT-X-MAP:') &&
      !line.startsWith('#EXT-X-MEDIA:')) {
    return line;
  }
  return line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
    final resolved = playlistUri.resolve(match.group(1)!);
    final isPlaylist = resolved.path.toLowerCase().endsWith('.m3u8');
    final local = localBaseUri.replace(
      path: isPlaylist ? '/playlist.m3u8' : '/segment',
      queryParameters: {'url': resolved.toString()},
    );
    return 'URI="$local"';
  });
}

class HlsProxyPlaybackSourceResolver {
  const HlsProxyPlaybackSourceResolver({
    required this.config,
    required this.proxyServer,
  });

  final HlsLocalProxyConfig config;
  final HlsLocalProxyServer proxyServer;

  Future<String> resolvePlayableSource(String remoteUrl) async {
    if (!config.enabled) {
      return remoteUrl;
    }
    final startedAt = DateTime.now();
    try {
      final proxyUrl = await proxyServer.proxyUrlFor(remoteUrl);
      const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
      if (shouldPrint) {
        debugPrint(
          '${DateTime.now().toIso8601String()} '
          'session=hls-local-proxy resolve playable source end '
          'elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds} '
          'source=$remoteUrl proxy=$proxyUrl',
        );
      }
      return proxyUrl;
    } catch (error) {
      // proxy 失败必须回退远端源，不能阻断播放。local proxy 是诊断 spike，
      // 任何启动端口、URL 重写或请求失败都不应扩大成业务不可播放。
      const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
      if (shouldPrint) {
        debugPrint(
          '${DateTime.now().toIso8601String()} '
          'session=hls-local-proxy fallback remote source source=$remoteUrl '
          'elapsedMs=${DateTime.now().difference(startedAt).inMilliseconds} '
          'error=$error',
        );
      }
      return remoteUrl;
    }
  }
}
