import 'dart:async';

import 'package:drama_client/features/player/data/hls_playlist_preloader.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playlist GET success returns preload success', () async {
    final client = _FakeHlsPlaylistHttpClient(
      response: const HlsPlaylistHttpResponse(
        statusCode: 200,
        body: '#EXTM3U\n#EXT-X-TARGETDURATION:6\n',
      ),
    );
    final manager = HlsPlayerPlaybackPreloadManager(
      preloader: HlsPlaylistPreloader(client: client),
    );

    final result = await manager.preload(
      item: _item(1),
      source: _source('https://cdn.example.test/drama/ep1.m3u8'),
    );

    expect(result.status, PlaybackPreloadStatus.success);
    expect(client.getCount, 1);
    expect(
      client.lastUri.toString(),
      'https://cdn.example.test/drama/ep1.m3u8',
    );
  });

  test(
    'master playlist is treated as a successful lightweight prefetch',
    () async {
      final client = _FakeHlsPlaylistHttpClient(
        response: const HlsPlaylistHttpResponse(
          statusCode: 200,
          body: '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nlow/index.m3u8\n',
        ),
      );
      final preloader = HlsPlaylistPreloader(client: client);

      final result = await preloader.prefetch(
        'https://cdn.example.test/master.m3u8',
      );

      expect(result.isMasterPlaylist, isTrue);
      expect(result.contentLength, greaterThan(0));
    },
  );

  test('HTTP non-2xx returns preload failed', () async {
    final manager = HlsPlayerPlaybackPreloadManager(
      preloader: HlsPlaylistPreloader(
        client: _FakeHlsPlaylistHttpClient(
          response: const HlsPlaylistHttpResponse(
            statusCode: 503,
            body: 'unavailable',
          ),
        ),
      ),
    );

    final result = await manager.preload(
      item: _item(1),
      source: _source('https://cdn.example.test/drama/ep1.m3u8'),
    );

    expect(result.status, PlaybackPreloadStatus.failed);
    expect(result.error, isA<HlsPlaylistPrefetchException>());
  });

  test('timeout returns preload failed', () async {
    final manager = HlsPlayerPlaybackPreloadManager(
      preloader: HlsPlaylistPreloader(
        client: _FakeHlsPlaylistHttpClient(pending: true),
        timeout: const Duration(milliseconds: 1),
      ),
    );

    final result = await manager.preload(
      item: _item(1),
      source: _source('https://cdn.example.test/drama/ep1.m3u8'),
    );

    expect(result.status, PlaybackPreloadStatus.failed);
    expect(result.error, isA<TimeoutException>());
  });

  test('malformed URL returns preload failed without GET', () async {
    final client = _FakeHlsPlaylistHttpClient(
      response: const HlsPlaylistHttpResponse(statusCode: 200, body: '#EXTM3U'),
    );
    final manager = HlsPlayerPlaybackPreloadManager(
      preloader: HlsPlaylistPreloader(client: client),
    );

    final result = await manager.preload(
      item: _item(1),
      source: _source('not-a-playlist'),
    );

    expect(result.status, PlaybackPreloadStatus.failed);
    expect(result.error, isA<FormatException>());
    expect(client.getCount, 0);
  });

  test(
    'cancelled pending prefetch returns cancelled and ignores late success',
    () async {
      final client = _FakeHlsPlaylistHttpClient(pending: true);
      final manager = HlsPlayerPlaybackPreloadManager(
        preloader: HlsPlaylistPreloader(client: client),
      );

      final preloadFuture = manager.preload(
        item: _item(1),
        source: _source('https://cdn.example.test/drama/ep1.m3u8'),
      );
      await Future<void>.delayed(Duration.zero);
      await manager.releasePending();
      client.complete(
        const HlsPlaylistHttpResponse(statusCode: 200, body: '#EXTM3U'),
      );

      final result = await preloadFuture;

      expect(result.status, PlaybackPreloadStatus.cancelled);
      expect(client.releasePendingCount, 1);
    },
  );
}

class _FakeHlsPlaylistHttpClient implements HlsPlaylistHttpClient {
  _FakeHlsPlaylistHttpClient({this.response, this.pending = false});

  final HlsPlaylistHttpResponse? response;
  final bool pending;
  final _completer = Completer<HlsPlaylistHttpResponse>();
  var getCount = 0;
  var releasePendingCount = 0;
  Uri? lastUri;

  @override
  Future<HlsPlaylistHttpResponse> get(
    Uri uri, {
    required Duration timeout,
  }) async {
    getCount += 1;
    lastUri = uri;
    if (pending) {
      return _completer.future;
    }
    return response!;
  }

  @override
  void releasePending() {
    releasePendingCount += 1;
  }

  void complete(HlsPlaylistHttpResponse response) {
    if (!_completer.isCompleted) {
      _completer.complete(response);
    }
  }
}

PlaybackSource _source(String url) {
  return PlaybackSource(
    itemId: 'drama-a-ep-1',
    remoteUrl: url,
    playableSource: url,
    cacheKey: 'player:drama-a:ep-1',
    expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    codecHint: 'hls',
    status: PlaybackSourceStatus.preloaded,
  );
}

PlayerFeedItem _item(int episodeNumber) {
  final episode = PlayerEpisode(
    id: 'ep-$episodeNumber',
    number: episodeNumber,
    isLocked: false,
    videoUrl: 'https://cdn.example.test/drama/ep$episodeNumber.m3u8',
  );
  final content = PlayerContent(
    id: 'drama-a',
    title: 'Drama A',
    playTitle: 'Drama A',
    synopsis: 'Synopsis',
    viewCountLabel: '1M Views',
    likeCountLabel: '1K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: [episode],
    recommendations: const [],
  );
  return PlayerFeedItem(
    id: '${content.id}-${episode.id}',
    mode: PlayerFeedMode.singleDrama,
    content: content,
    episode: episode,
  );
}
