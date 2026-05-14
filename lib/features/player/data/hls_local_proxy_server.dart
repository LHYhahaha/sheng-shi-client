import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class HlsLocalProxyConfig {
  const HlsLocalProxyConfig({
    this.enabled = false,
    this.timeout = const Duration(seconds: 4),
  });

  final bool enabled;
  final Duration timeout;
}

class HlsLocalProxyResponse {
  const HlsLocalProxyResponse({
    required this.statusCode,
    required this.bytes,
    this.contentType,
  });

  final int statusCode;
  final List<int> bytes;
  final String? contentType;

  String get body => utf8.decode(bytes, allowMalformed: true);
}

abstract interface class HlsLocalProxyHttpClient {
  Future<HlsLocalProxyResponse> get(Uri uri, {required Duration timeout});

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

class HlsLocalCacheStore {
  final _bytesByUrl = <String, List<int>>{};

  bool contains(String url) => _bytesByUrl.containsKey(url);

  List<int>? read(String url) => _bytesByUrl[url];

  void write(String url, List<int> bytes) {
    _bytesByUrl[url] = List<int>.unmodifiable(bytes);
  }

  void clear() => _bytesByUrl.clear();
}

class HlsLocalProxyServer {
  HlsLocalProxyServer({
    HlsLocalProxyHttpClient? client,
    HlsLocalCacheStore? cacheStore,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client ?? DartIoHlsLocalProxyHttpClient(),
       _cacheStore = cacheStore ?? HlsLocalCacheStore();

  final HlsLocalProxyHttpClient _client;
  final HlsLocalCacheStore _cacheStore;
  final Duration timeout;
  HttpServer? _server;
  var _generation = 0;

  bool get isRunning => _server != null;

  Future<String> proxyUrlFor(String remoteUrl) async {
    final remoteUri = _parseRemoteUri(remoteUrl);
    final server = await _ensureStarted();
    final proxyUri = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/playlist.m3u8',
      queryParameters: {'url': remoteUri.toString()},
    );
    _log('proxy source generated source=$remoteUrl proxy=$proxyUri');
    return proxyUri.toString();
  }

  Future<void> stop() async {
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
    final response = await _fetch(remoteUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await _sendText(
        request,
        HttpStatus.badGateway,
        'Playlist fetch failed: ${response.statusCode}',
      );
      return;
    }
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
      'playlist proxy fetch miss source=$remoteUri '
      'elapsedMs=${_elapsedMs(startedAt)} bytes=${response.bytes.length}',
    );
  }

  Future<void> _proxySegment(HttpRequest request, Uri remoteUri) async {
    final cacheKey = remoteUri.toString();
    final cachedBytes = _cacheStore.read(cacheKey);
    if (cachedBytes != null) {
      await _sendBytes(request, cachedBytes);
      _log(
        'segment proxy fetch hit source=$remoteUri bytes=${cachedBytes.length}',
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
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      return line;
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
    try {
      return await proxyServer.proxyUrlFor(remoteUrl);
    } catch (error) {
      const shouldPrint = bool.fromEnvironment('PLAYER_TIMING_LOGS');
      if (shouldPrint) {
        debugPrint(
          '${DateTime.now().toIso8601String()} '
          'session=hls-local-proxy fallback remote source source=$remoteUrl '
          'error=$error',
        );
      }
      return remoteUrl;
    }
  }
}
