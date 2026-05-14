import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/player_feed.dart';
import '../domain/player_playback_source.dart';
import '../domain/player_preload_state.dart';

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

  final String url;
  final int contentLength;
  final bool isMasterPlaylist;
  final DateTime fetchedAt;
  final String mediaPlaylistUrl;
  final List<String> segmentUrls;
  final int segmentBytesPreheated;
  final List<String> diagnostics;
}

class HlsPlaylistPrefetchException implements Exception {
  const HlsPlaylistPrefetchException(this.message);

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
  });

  final int statusCode;
  final String body;
  final int? contentLength;

  int get byteLength => contentLength ?? utf8.encode(body).length;
}

abstract interface class HlsPlaylistHttpClient {
  Future<HlsPlaylistHttpResponse> get(Uri uri, {required Duration timeout});

  void releasePending();
}

class DartIoHlsPlaylistHttpClient implements HlsPlaylistHttpClient {
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

class HlsPlaylistPreloader {
  HlsPlaylistPreloader({
    HlsPlaylistHttpClient? client,
    this.timeout = const Duration(seconds: 4),
    this.maxSegments = 2,
    this.maxPreheatBytes = 2 * 1024 * 1024,
  }) : _client = client ?? DartIoHlsPlaylistHttpClient();

  final HlsPlaylistHttpClient _client;
  final Duration timeout;
  final int maxSegments;
  final int maxPreheatBytes;
  int _generation = 0;

  Future<HlsPlaylistPrefetchResult> prefetch(String sourceUrl) async {
    final generation = _generation;
    final uri = _parseHttpUri(sourceUrl);
    final diagnostics = <String>[];

    final playlistStartedAt = DateTime.now();
    diagnostics.add('hls master playlist fetch start');
    final response = await _getOrThrow(uri, generation: generation);
    diagnostics.add(
      'hls master playlist fetch end ${_elapsedMs(playlistStartedAt)}ms',
    );

    final isMasterPlaylist = response.body.contains('#EXT-X-STREAM-INF');
    var mediaPlaylistUri = uri;
    var mediaPlaylistBody = response.body;
    var contentLength = response.byteLength;

    if (isMasterPlaylist) {
      final variantUri = _selectVariantUri(uri, response.body);
      if (variantUri != null) {
        final mediaStartedAt = DateTime.now();
        diagnostics.add('hls media playlist fetch start');
        final mediaResponse = await _getOrThrow(
          variantUri,
          generation: generation,
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

    final segmentUris = _parseSegmentUris(
      mediaPlaylistUri,
      mediaPlaylistBody,
    ).take(maxSegments).toList(growable: false);
    final preheatedSegments = <Uri>[];
    var segmentBytesPreheated = 0;

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
    _generation += 1;
    _client.releasePending();
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
    final response = await _client.get(uri, timeout: timeout).timeout(timeout);
    if (generation != _generation) {
      throw const HlsPlaylistPreloadCancelledException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HlsPlaylistPrefetchException(
        'HLS request failed with HTTP ${response.statusCode}: $uri',
      );
    }
    return response;
  }

  Uri? _selectVariantUri(Uri masterUri, String playlistBody) {
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
          _HlsVariant(uri: masterUri.resolve(uriLine), bandwidth: bandwidth),
        );
        break;
      }
    }
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

  int? _parseBandwidth(String streamInfLine) {
    final match = RegExp(r'BANDWIDTH=(\d+)').firstMatch(streamInfLine);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  List<Uri> _parseSegmentUris(Uri mediaPlaylistUri, String playlistBody) {
    return const LineSplitter()
        .convert(playlistBody)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map(mediaPlaylistUri.resolve)
        .toList(growable: false);
  }

  int _elapsedMs(DateTime startedAt) {
    return DateTime.now().difference(startedAt).inMilliseconds;
  }
}

class _HlsVariant {
  const _HlsVariant({required this.uri, required this.bandwidth});

  final Uri uri;
  final int? bandwidth;
}

class HlsPlayerPlaybackPreloadManager implements PlayerPlaybackPreloadManager {
  HlsPlayerPlaybackPreloadManager({required HlsPlaylistPreloader preloader})
    : _preloader = preloader;

  final HlsPlaylistPreloader _preloader;

  @override
  Future<PlaybackPreloadState> preload({
    required PlayerFeedItem item,
    required PlaybackSource source,
  }) async {
    final startedAt = DateTime.now();
    try {
      final result = await _preloader.prefetch(source.playableSource);
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
