import 'dart:async';

import 'package:drama_client/features/player/data/hls_playlist_preloader.dart';
import 'package:drama_client/features/player/data/hls_local_proxy_server.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/data/player_preload_config_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/domain/player_preload_config.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preloader provider uses typed timeout and max byte config', () {
    final container = ProviderContainer(
      overrides: [
        playerPreloadConfigProvider.overrideWithValue(
          const PlayerPreloadConfig(
            preloadTimeout: Duration(milliseconds: 900),
            maxPreloadBytes: 1234,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final preloader = container.read(hlsPlaylistPreloaderProvider);

    expect(preloader.timeout, const Duration(milliseconds: 900));
    expect(preloader.sharedRequestTimeout, const Duration(seconds: 12));
    expect(preloader.maxPreheatBytes, 1234);
  });

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
    'master playlist resolves lowest variant and preheats first segments',
    () async {
      final client = _FakeHlsPlaylistHttpClient(
        responses: const {
          'https://cdn.example.test/master.m3u8': HlsPlaylistHttpResponse(
            statusCode: 200,
            body:
                '#EXTM3U\n'
                '#EXT-X-STREAM-INF:BANDWIDTH=2000000\n'
                'high/index.m3u8\n'
                '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
                'low/index.m3u8\n',
          ),
          'https://cdn.example.test/low/index.m3u8': HlsPlaylistHttpResponse(
            statusCode: 200,
            body:
                '#EXTM3U\n'
                '#EXT-X-TARGETDURATION:4\n'
                '#EXTINF:4,\n'
                'seg1.ts\n'
                '#EXTINF:4,\n'
                '../seg2.ts\n'
                '#EXTINF:4,\n'
                'seg3.ts\n',
          ),
          'https://cdn.example.test/low/seg1.ts': HlsPlaylistHttpResponse(
            statusCode: 200,
            body: 'aaaa',
          ),
          'https://cdn.example.test/seg2.ts': HlsPlaylistHttpResponse(
            statusCode: 200,
            body: 'bbbb',
          ),
        },
      );
      final cacheStore = HlsLocalCacheStore();
      final preloader = HlsPlaylistPreloader(
        client: client,
        cacheStore: cacheStore,
      );

      final result = await preloader.prefetch(
        'https://cdn.example.test/master.m3u8',
      );

      expect(result.isMasterPlaylist, isTrue);
      expect(
        cacheStore.contains('https://cdn.example.test/master.m3u8'),
        isTrue,
      );
      expect(
        cacheStore.contains('https://cdn.example.test/low/seg1.ts'),
        isTrue,
      );
      expect(
        result.mediaPlaylistUrl,
        'https://cdn.example.test/low/index.m3u8',
      );
      expect(result.segmentUrls, [
        'https://cdn.example.test/low/seg1.ts',
        'https://cdn.example.test/seg2.ts',
      ]);
      expect(result.segmentBytesPreheated, 8);
      expect(result.contentLength, greaterThan(0));
      expect(client.requestedUris.map((uri) => uri.toString()), [
        'https://cdn.example.test/master.m3u8',
        'https://cdn.example.test/low/index.m3u8',
        'https://cdn.example.test/low/seg1.ts',
        'https://cdn.example.test/seg2.ts',
      ]);
    },
  );

  test('media playlist directly preheats relative segments', () async {
    final client = _FakeHlsPlaylistHttpClient(
      responses: const {
        'https://cdn.example.test/drama/ep1/index.m3u8':
            HlsPlaylistHttpResponse(
              statusCode: 200,
              body:
                  '#EXTM3U\n'
                  '#EXTINF:4,\n'
                  'segments/first.ts\n'
                  '#EXTINF:4,\n'
                  '/shared/second.ts\n',
            ),
        'https://cdn.example.test/drama/ep1/segments/first.ts':
            HlsPlaylistHttpResponse(statusCode: 200, body: 'first'),
        'https://cdn.example.test/shared/second.ts': HlsPlaylistHttpResponse(
          statusCode: 200,
          body: 'second',
        ),
      },
    );
    final preloader = HlsPlaylistPreloader(client: client);

    final result = await preloader.prefetch(
      'https://cdn.example.test/drama/ep1/index.m3u8',
    );

    expect(result.isMasterPlaylist, isFalse);
    expect(result.segmentUrls, [
      'https://cdn.example.test/drama/ep1/segments/first.ts',
      'https://cdn.example.test/shared/second.ts',
    ]);
    expect(result.segmentBytesPreheated, 11);
  });

  test(
    'resume preheat covers decoder bootstrap and the saved-position segment',
    () async {
      final client = _FakeHlsPlaylistHttpClient(
        responses: const {
          'https://cdn.example.test/drama/ep1.m3u8': HlsPlaylistHttpResponse(
            statusCode: 200,
            body:
                '#EXTM3U\n'
                '#EXTINF:4,\n'
                'first.ts\n'
                '#EXTINF:4,\n'
                'second.ts\n'
                '#EXTINF:4,\n'
                'third.ts\n'
                '#EXTINF:4,\n'
                'fourth.ts\n',
          ),
          'https://cdn.example.test/drama/first.ts': HlsPlaylistHttpResponse(
            statusCode: 200,
            body: 'first',
          ),
          'https://cdn.example.test/drama/third.ts': HlsPlaylistHttpResponse(
            statusCode: 200,
            body: 'third',
          ),
          'https://cdn.example.test/drama/fourth.ts': HlsPlaylistHttpResponse(
            statusCode: 200,
            body: 'fourth',
          ),
        },
      );
      final preloader = HlsPlaylistPreloader(client: client);

      final result = await preloader.prefetch(
        'https://cdn.example.test/drama/ep1.m3u8',
        preferredPosition: const Duration(seconds: 9),
      );

      expect(result.segmentUrls, [
        'https://cdn.example.test/drama/first.ts',
        'https://cdn.example.test/drama/third.ts',
      ]);
      expect(
        client.requestedUris.map((uri) => uri.toString()),
        isNot(contains('https://cdn.example.test/drama/second.ts')),
      );
    },
  );

  test('max bytes stops additional segment preheat', () async {
    final client = _FakeHlsPlaylistHttpClient(
      responses: const {
        'https://cdn.example.test/drama/ep1.m3u8': HlsPlaylistHttpResponse(
          statusCode: 200,
          body:
              '#EXTM3U\n'
              '#EXTINF:4,\n'
              'first.ts\n'
              '#EXTINF:4,\n'
              'second.ts\n',
        ),
        'https://cdn.example.test/drama/first.ts': HlsPlaylistHttpResponse(
          statusCode: 200,
          body: '123456',
        ),
        'https://cdn.example.test/drama/second.ts': HlsPlaylistHttpResponse(
          statusCode: 200,
          body: '12',
        ),
      },
    );
    final preloader = HlsPlaylistPreloader(client: client, maxPreheatBytes: 4);

    final result = await preloader.prefetch(
      'https://cdn.example.test/drama/ep1.m3u8',
    );

    expect(result.segmentUrls, ['https://cdn.example.test/drama/first.ts']);
    expect(result.segmentBytesPreheated, 6);
    expect(
      client.requestedUris.map((uri) => uri.toString()),
      isNot(contains('https://cdn.example.test/drama/second.ts')),
    );
  });

  test('small remaining byte budget does not fetch another segment', () async {
    const firstSegmentBytes = 2 * 1024 * 1024 - 1024;
    final client = _FakeHlsPlaylistHttpClient(
      responses: {
        'https://cdn.example.test/drama/ep1.m3u8':
            const HlsPlaylistHttpResponse(
              statusCode: 200,
              body:
                  '#EXTM3U\n'
                  '#EXTINF:4,\n'
                  'first.ts\n'
                  '#EXTINF:4,\n'
                  'second.ts\n',
            ),
        'https://cdn.example.test/drama/first.ts': HlsPlaylistHttpResponse(
          statusCode: 200,
          body: 'first',
          contentLength: firstSegmentBytes,
        ),
        'https://cdn.example.test/drama/second.ts':
            const HlsPlaylistHttpResponse(statusCode: 200, body: 'second'),
      },
    );
    final preloader = HlsPlaylistPreloader(
      client: client,
      maxPreheatBytes: 2 * 1024 * 1024,
    );

    final result = await preloader.prefetch(
      'https://cdn.example.test/drama/ep1.m3u8',
    );

    expect(result.segmentUrls, ['https://cdn.example.test/drama/first.ts']);
    expect(result.segmentBytesPreheated, firstSegmentBytes);
    expect(
      client.requestedUris.map((uri) => uri.toString()),
      isNot(contains('https://cdn.example.test/drama/second.ts')),
    );
  });

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

  test(
    'preload wait budget does not shorten a shared request lifetime',
    () async {
      final client = _FakeHlsPlaylistHttpClient(pending: true);
      final preloader = HlsPlaylistPreloader(
        client: client,
        timeout: const Duration(milliseconds: 1),
        sharedRequestTimeout: const Duration(seconds: 12),
      );

      final future = preloader.prefetch(
        'https://cdn.example.test/drama/ep1.m3u8',
      );
      await expectLater(future, throwsA(isA<TimeoutException>()));
      expect(client.lastTimeout, const Duration(seconds: 12));

      // 请求仍在运行；真实播放可以在 coordinator 中加入它，而不是重新回源。
      client.complete(
        null,
        const HlsPlaylistHttpResponse(statusCode: 200, body: '#EXTM3U'),
      );
    },
  );

  test('segment GET failure returns preload failed', () async {
    final manager = HlsPlayerPlaybackPreloadManager(
      preloader: HlsPlaylistPreloader(
        client: _FakeHlsPlaylistHttpClient(
          responses: const {
            'https://cdn.example.test/drama/ep1.m3u8': HlsPlaylistHttpResponse(
              statusCode: 200,
              body: '#EXTM3U\n#EXTINF:4,\nfirst.ts\n',
            ),
            'https://cdn.example.test/drama/first.ts': HlsPlaylistHttpResponse(
              statusCode: 503,
              body: 'bad edge',
            ),
          },
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
      final cacheStore = HlsLocalCacheStore();
      final manager = HlsPlayerPlaybackPreloadManager(
        preloader: HlsPlaylistPreloader(client: client, cacheStore: cacheStore),
      );

      final preloadFuture = manager.preload(
        item: _item(1),
        source: _source('https://cdn.example.test/drama/ep1.m3u8'),
      );
      await Future<void>.delayed(Duration.zero);
      await manager.releasePending();
      client.complete(
        null,
        const HlsPlaylistHttpResponse(statusCode: 200, body: '#EXTM3U'),
      );

      final result = await preloadFuture;

      expect(result.status, PlaybackPreloadStatus.cancelled);
      expect(client.releasePendingCount, 0);
      expect(
        cacheStore.contains('https://cdn.example.test/drama/ep1.m3u8'),
        isTrue,
      );
    },
  );

  test(
    'cancelled pending segment preheat returns cancelled without late success',
    () async {
      final segmentUrl = 'https://cdn.example.test/drama/first.ts';
      final client = _FakeHlsPlaylistHttpClient(
        pendingUrls: {segmentUrl},
        responses: const {
          'https://cdn.example.test/drama/ep1.m3u8': HlsPlaylistHttpResponse(
            statusCode: 200,
            body: '#EXTM3U\n#EXTINF:4,\nfirst.ts\n',
          ),
        },
      );
      final manager = HlsPlayerPlaybackPreloadManager(
        preloader: HlsPlaylistPreloader(client: client),
      );

      final preloadFuture = manager.preload(
        item: _item(1),
        source: _source('https://cdn.example.test/drama/ep1.m3u8'),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await manager.releasePending();
      client.complete(
        segmentUrl,
        const HlsPlaylistHttpResponse(statusCode: 200, body: 'segment'),
      );

      final result = await preloadFuture;

      expect(result.status, PlaybackPreloadStatus.cancelled);
      expect(client.releasePendingCount, 0);
    },
  );
}

class _FakeHlsPlaylistHttpClient implements HlsPlaylistHttpClient {
  _FakeHlsPlaylistHttpClient({
    this.response,
    this.responses = const {},
    this.pending = false,
    this.pendingUrls = const {},
  });

  final HlsPlaylistHttpResponse? response;
  final Map<String, HlsPlaylistHttpResponse> responses;
  final bool pending;
  final Set<String> pendingUrls;
  final _globalCompleter = Completer<HlsPlaylistHttpResponse>();
  final _pendingCompleters = <String, Completer<HlsPlaylistHttpResponse>>{};
  final requestedUris = <Uri>[];
  var getCount = 0;
  var releasePendingCount = 0;
  Uri? lastUri;
  Duration? lastTimeout;

  @override
  Future<HlsPlaylistHttpResponse> get(
    Uri uri, {
    required Duration timeout,
  }) async {
    getCount += 1;
    lastUri = uri;
    lastTimeout = timeout;
    requestedUris.add(uri);
    final uriText = uri.toString();
    if (pendingUrls.contains(uriText)) {
      return _pendingCompleters
          .putIfAbsent(uriText, Completer<HlsPlaylistHttpResponse>.new)
          .future;
    }
    if (pending) {
      return _globalCompleter.future;
    }
    return responses[uriText] ?? response!;
  }

  @override
  void releasePending() {
    releasePendingCount += 1;
  }

  void complete(String? uri, HlsPlaylistHttpResponse response) {
    if (uri == null) {
      if (!_globalCompleter.isCompleted) {
        _globalCompleter.complete(response);
      }
      return;
    }
    final completer = _pendingCompleters[uri];
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
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
    episodeTotal: 1,
  );
  return PlayerFeedItem(
    id: '${content.id}-${episode.id}',
    mode: PlayerFeedMode.singleDrama,
    content: content,
    episode: episode,
  );
}
