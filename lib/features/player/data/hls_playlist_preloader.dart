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
  });

  final String url;
  final int contentLength;
  final bool isMasterPlaylist;
  final DateTime fetchedAt;
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
  const HlsPlaylistHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
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
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      return HlsPlaylistHttpResponse(
        statusCode: response.statusCode,
        body: body,
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
  }) : _client = client ?? DartIoHlsPlaylistHttpClient();

  final HlsPlaylistHttpClient _client;
  final Duration timeout;
  int _generation = 0;

  Future<HlsPlaylistPrefetchResult> prefetch(String sourceUrl) async {
    final generation = _generation;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw FormatException('Invalid HLS playlist URL.', sourceUrl);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw FormatException('Unsupported HLS playlist URL scheme.', sourceUrl);
    }

    final response = await _client.get(uri, timeout: timeout).timeout(timeout);
    if (generation != _generation) {
      throw const HlsPlaylistPreloadCancelledException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HlsPlaylistPrefetchException(
        'Playlist request failed with HTTP ${response.statusCode}.',
      );
    }

    return HlsPlaylistPrefetchResult(
      url: sourceUrl,
      contentLength: response.body.length,
      isMasterPlaylist: response.body.contains('#EXT-X-STREAM-INF'),
      fetchedAt: DateTime.now(),
    );
  }

  void releasePending() {
    _generation += 1;
    _client.releasePending();
  }
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
      await _preloader.prefetch(source.playableSource);
      return PlaybackPreloadState(
        itemId: item.id,
        sourceUrl: source.playableSource,
        status: PlaybackPreloadStatus.success,
        startedAt: startedAt,
        completedAt: DateTime.now(),
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
