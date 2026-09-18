import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/network/api_client.dart';
import 'package:drama_client/core/network/api_exception.dart';
import 'package:drama_client/core/network/api_mapping_exception.dart';
import 'package:drama_client/core/network/api_request_context.dart';
import 'package:drama_client/features/player/data/dto/playback_source_dto.dart';
import 'package:drama_client/features/player/data/dto/player_content_dto.dart';
import 'package:drama_client/features/player/data/dto/player_episode_dto.dart';
import 'package:drama_client/features/player/data/dto/player_feed_item_dto.dart';
import 'package:drama_client/features/player/data/dto/player_feed_page_dto.dart';
import 'package:drama_client/features/player/data/mapper/playback_source_mapper.dart';
import 'package:drama_client/features/player/data/mapper/player_content_mapper.dart';
import 'package:drama_client/features/player/data/mock_player_content_repository.dart';
import 'package:drama_client/features/player/data/mock_player_feed_repository.dart';
import 'package:drama_client/features/player/data/mock_player_playback_source_repository.dart';
import 'package:drama_client/features/player/data/player_content_repository_provider.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/data/player_playback_source_repository_provider.dart';
import 'package:drama_client/features/player/data/remote/playback_source_remote_data_source.dart';
import 'package:drama_client/features/player/data/remote/player_remote_data_source.dart';
import 'package:drama_client/features/player/data/remote_player_content_repository.dart';
import 'package:drama_client/features/player/data/remote_player_feed_repository.dart';
import 'package:drama_client/features/player/data/remote_player_playback_source_repository.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:drama_client/features/player/domain/player_playback_source.dart';
import 'package:drama_client/features/player/domain/player_preload_state.dart';

void main() {
  const contentMapper = PlayerContentMapper();
  const sourceMapper = PlaybackSourceMapper();

  test('player content dto maps to PlayerContent and episodes', () {
    final content = contentMapper.mapContent(
      _playerContentDto(episodes: [_contentCoinEpisode]),
    );

    expect(content.id, '1');
    expect(content.title, 'Found You');
    expect(content.synopsis, 'Remote synopsis');
    expect(content.viewCountLabel, '52.0M');
    expect(content.episodes, hasLength(1));
    expect(content.episodes.single.id, '4');
    expect(content.episodes.single.number, 4);
    expect(content.episodes.single.isAvailable, isTrue);
    expect(content.episodes.single.duration, const Duration(seconds: 60));
  });

  test('unavailable episode dto maps to unavailable domain episode', () {
    final episode = contentMapper.mapEpisode(_unavailableEpisode);

    expect(episode.isUnavailable, isTrue);
    expect(episode.isAvailable, isFalse);
  });

  test('taken-down drama makes every episode unavailable', () {
    final content = contentMapper.mapContent(
      PlayerContentDto.fromJson({
        'id': 1,
        'status': 2,
        'episodes': [
          {
            'id': 4,
            'episode_no': 1,
            'status': 1,
            'is_unlocked': 1,
            'source_url': 'https://example.com/episode.m3u8',
          },
        ],
      }),
    );

    expect(content.isDramaAvailable, isFalse);
    expect(content.episodes.single.isUnavailable, isTrue);
  });

  test('for you page dto parses paged drama response and active episode', () {
    final page = PlayerFeedPageDto.fromJson({
      'page': 2,
      'page_size': 20,
      'total': 45,
      'dramas': [
        {
          'id': 154,
          'cover_url': 'https://example.com/154.jpg',
          'title': 'Drama 154',
          'summary': '',
          'play_count': 1000000,
          'favorite_count': 1234,
          'is_favorited': 1,
          'trailer_episode_num': 5,
          'is_vip_only': 1,
          'status': 1,
          'episode_total': 3,
          'episode_id': 502,
          'episode_no': 2,
          'episodes': [
            {
              'id': 501,
              'episode_no': 1,
              'source_url': 'https://example.com/501.m3u8',
              'status': 1,
              'is_unlocked': 1,
              'is_vip_only': 0,
              'subtitles': <Object?>[],
            },
            {
              'id': 502,
              'episode_no': 2,
              'source_url': 'https://example.com/502.m3u8',
              'status': 1,
              'is_unlocked': 1,
              'is_vip_only': 0,
              'subtitles': <Object?>[],
            },
          ],
        },
      ],
    });

    expect(page.page, 2);
    expect(page.pageSize, 20);
    expect(page.total, 45);
    expect(page.hasMore, isTrue);
    expect(page.items, hasLength(1));
    expect(page.items.single.dramaId, '154');
    expect(page.items.single.episodeId, '502');
    expect(page.items.single.episode.id, 502);
    expect(page.items.single.drama.favoriteCount, 1234);
    expect(page.items.single.drama.isFavorited, isTrue);
    expect(page.items.single.drama.episodes, hasLength(2));
  });

  test('playback source dto maps cache key with sourceId and expiry', () {
    final item = _feedItem();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    final source = sourceMapper.mapSource(
      _playbackSource(
        sourceId: 'source-a',
        hlsUrl: 'https://cdn.example.com/a.m3u8',
        expiresAt: expiresAt,
        durationMs: 60000,
        width: 1080,
        height: 1920,
        aspectRatio: 9 / 16,
        codec: 'hls',
        cachePolicy: const {'ttl': 300},
        preloadPolicy: const {'level': 'playlist'},
        previewSpriteUrl: 'https://cdn.example.com/sprite.jpg',
        previewVttUrl: 'https://cdn.example.com/sprite.vtt',
      ),
      item: item,
      status: PlaybackSourceStatus.resolved,
    );

    expect(source.itemId, item.id);
    expect(source.remoteUrl, 'https://cdn.example.com/a.m3u8');
    expect(source.playableSource, 'https://cdn.example.com/a.m3u8');
    expect(source.cacheKey, 'player:found-you:ep-1:source-a');
    expect(source.expiresAt, expiresAt);
    expect(source.codecHint, 'hls');
  });

  test('same HLS url with different sourceId gets different cache keys', () {
    final item = _feedItem();
    final sourceA = sourceMapper.mapSource(
      _playbackSource(sourceId: 'source-a'),
      item: item,
      status: PlaybackSourceStatus.resolved,
    );
    final sourceB = sourceMapper.mapSource(
      _playbackSource(sourceId: 'source-b'),
      item: item,
      status: PlaybackSourceStatus.resolved,
    );

    expect(sourceA.remoteUrl, sourceB.remoteUrl);
    expect(sourceA.cacheKey, isNot(sourceB.cacheKey));
  });

  test('missing hlsUrl throws instead of creating invalid source', () {
    final item = _feedItem();

    expect(
      () => sourceMapper.mapSource(
        _playbackSource(hlsUrl: ''),
        item: item,
        status: PlaybackSourceStatus.resolved,
      ),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test(
    'expired playback source throws instead of creating playable source',
    () {
      final item = _feedItem();
      final expiredAt = DateTime.now().subtract(const Duration(minutes: 1));

      expect(
        () => sourceMapper.mapSource(
          _playbackSource(
            sourceId: 'expired-source',
            hlsUrl: 'https://cdn.example.com/expired.m3u8',
            expiresAt: expiredAt,
          ),
          item: item,
          status: PlaybackSourceStatus.resolved,
        ),
        throwsA(isA<ApiMappingException>()),
      );
    },
  );

  test('access denied playback source throws with reason contract', () {
    final item = _feedItem();

    expect(
      () => sourceMapper.mapSource(
        _playbackSource(
          sourceId: 'blocked-source',
          hlsUrl: 'https://cdn.example.com/blocked.m3u8',
          isAvailable: false,
          accessStatus: 'denied',
          reasonCode: 'ENTITLEMENT_REQUIRED',
        ),
        item: item,
        status: PlaybackSourceStatus.resolved,
      ),
      throwsA(isA<ApiMappingException>()),
    );
  });

  test('playback source dto parses nested access contract', () {
    final dto = PlaybackSourceDto.fromJson({
      'episodeId': 'ep-1',
      'sourceId': 'source-a',
      'hlsUrl': 'https://cdn.example.com/a.m3u8',
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
      'isAvailable': true,
      'access': {'status': 'denied', 'reasonCode': 'REGION_BLOCKED'},
    });

    expect(dto.accessStatus, 'denied');
    expect(dto.reasonCode, 'REGION_BLOCKED');
    expect(dto.hasPlayableHls, isFalse);
  });

  test('remote content repository combines detail and episode list', () async {
    final repository = RemotePlayerContentRepository(
      remoteDataSource: _FakePlayerRemoteDataSource(
        detail: _playerContentDto(
          episodes: [_contentFreeEpisode, _contentCoinEpisode],
        ),
      ),
    );

    final content = await repository.getPlayerContent(dramaId: '1');

    expect(content.id, '1');
    expect(content.episodes.map((episode) => episode.id), ['1', '4']);
  });

  test(
    'remote feed repository maps single drama feed with stable ids in episode order',
    () async {
      final repository = RemotePlayerFeedRepository(
        remoteDataSource: _FakePlayerRemoteDataSource(
          detail: _playerContentDto(
            episodes: [_contentFreeEpisode, _contentCoinEpisode],
          ),
        ),
      );

      final items = await repository.listSingleDramaFeed(
        dramaId: '1',
        episodeId: '4',
      );

      expect(items.map((item) => item.id), ['single:1:1', 'single:1:4']);
      expect(items.map((item) => item.episode.number), [1, 4]);
    },
  );

  test('remote feed repository maps for you feed items', () async {
    final repository = RemotePlayerFeedRepository(
      remoteDataSource: _FakePlayerRemoteDataSource(
        forYouPage: PlayerFeedPageDto(
          items: [
            PlayerFeedItemDto(
              feedItemId: 'remote-feed-1',
              dramaId: 'found-you',
              episodeId: 'ep-1',
              reason: 'rank',
              rankingScore: 98,
              drama: _playerContentDto(),
              episode: _freeEpisode,
            ),
          ],
          page: 1,
          pageSize: 20,
          total: 21,
        ),
      ),
    );

    final items = await repository.listForYouFeed();

    expect(items, hasLength(1));
    expect(items.single.id, 'remote-feed-1');
    expect(items.single.mode, PlayerFeedMode.forYou);
  });

  test(
    'remote playback source repository resolves and preloads source',
    () async {
      final preloadManager = MockPlayerPlaybackPreloadManager(
        preloadDelay: Duration.zero,
      );
      final repository = RemotePlayerPlaybackSourceRepository(
        remoteDataSource: _FakePlaybackSourceRemoteDataSource(
          source: _playbackSource(
            hlsUrl: 'https://cdn.example.com/a.m3u8',
            codec: 'hls',
          ),
        ),
        preloadManager: preloadManager,
        httpHeaders: const {'Authorization': 'Bearer token-1'},
      );
      final item = _feedItem();

      final resolved = await repository.resolve(item);
      final preloaded = await repository.preload(item);

      expect(resolved.remoteUrl, 'https://cdn.example.com/a.m3u8');
      expect(resolved.httpHeaders, {'Authorization': 'Bearer token-1'});
      expect(preloaded.status, PlaybackPreloadStatus.success);
      expect(preloadManager.preloadCount, 1);
    },
  );

  test(
    'remote playback source repository resolves a CDN root through playback source API',
    () async {
      final remoteDataSource = _FakePlaybackSourceRemoteDataSource(
        source: _playbackSource(hlsUrl: 'https://cdn.example.com/episode.m3u8'),
      );
      final repository = RemotePlayerPlaybackSourceRepository(
        remoteDataSource: remoteDataSource,
        preloadManager: MockPlayerPlaybackPreloadManager(
          preloadDelay: Duration.zero,
        ),
      );
      final item = _feedItem(videoSource: 'https://cdn.example.com/');

      final resolved = await repository.resolve(item);

      expect(resolved.remoteUrl, 'https://cdn.example.com/episode.m3u8');
      expect(remoteDataSource.requestedEpisodeIds, ['ep-1']);
    },
  );

  test('playback source remote datasource requires auth policy', () async {
    final adapter = _FakeHttpClientAdapter(
      responseData: {
        'code': 0,
        'message': 'success',
        'data': {
          'episodeId': 'ep-1',
          'sourceId': 'source-a',
          'hlsUrl': 'https://cdn.example.com/a.m3u8',
          'expiresAt': '2026-12-31T00:00:00Z',
          'isAvailable': true,
        },
      },
    );
    final client = ApiClient(
      dio: Dio()..httpClientAdapter = adapter,
      requestContext: const ApiRequestContext(
        deviceId: 'device-1',
        lang: 'en',
        platform: 'android',
        appVersion: '1.0.0',
        accessToken: 'token-1',
      ),
    );
    final dataSource = PlaybackSourceRemoteDataSource(apiClient: client);

    final dto = await dataSource.getPlaybackSource(episodeId: 'ep-1');

    expect(dto.sourceId, 'source-a');
    expect(adapter.lastOptions!.headers['Authorization'], 'Bearer token-1');
  });

  test(
    'playback source remote datasource preserves business code failures',
    () {
      final adapter = _FakeHttpClientAdapter(
        responseData: {'code': 3001, 'message': 'source expired', 'data': null},
      );
      final client = ApiClient(
        dio: Dio()..httpClientAdapter = adapter,
        requestContext: const ApiRequestContext(
          deviceId: 'device-1',
          lang: 'en',
          platform: 'android',
          appVersion: '1.0.0',
          accessToken: 'token-1',
        ),
      );
      final dataSource = PlaybackSourceRemoteDataSource(apiClient: client);

      final future = dataSource.getPlaybackSource(episodeId: 'ep-1');

      expect(
        future,
        throwsA(
          isA<ApiException>()
              .having((error) => error.businessCode, 'businessCode', 3001)
              .having((error) => error.message, 'message', 'source expired'),
        ),
      );
    },
  );

  test(
    'player feed provider uses remote repository when the switch is enabled',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(playerFeedRepositoryProvider),
        isA<RemotePlayerFeedRepository>(),
      );
    },
  );

  test(
    'player feed provider uses mock repository when the switch is disabled',
    () {
      final container = ProviderContainer(
        overrides: [useRemotePlayerApiProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(playerFeedRepositoryProvider),
        isA<MockPlayerFeedRepository>(),
      );
    },
  );

  test('remote switch provider can enable remote repository skeletons', () {
    final container = ProviderContainer(
      overrides: [useRemotePlayerApiProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(playerContentRepositoryProvider),
      isA<RemotePlayerContentRepository>(),
    );
    expect(
      container.read(playerFeedRepositoryProvider),
      isA<RemotePlayerFeedRepository>(),
    );
    expect(
      container.read(playerPlaybackSourceRepositoryProvider),
      isA<RemotePlayerPlaybackSourceRepository>(),
    );
  });
}

PlaybackSourceDto _playbackSource({
  String episodeId = 'ep-1',
  String sourceId = 'source-a',
  String hlsUrl = 'https://cdn.example.com/shared.m3u8',
  DateTime? expiresAt,
  int? durationMs,
  int? width,
  int? height,
  double? aspectRatio,
  String? codec,
  Map<String, Object?> cachePolicy = const {},
  Map<String, Object?> preloadPolicy = const {},
  String? previewSpriteUrl,
  String? previewVttUrl,
  bool isAvailable = true,
  String? accessStatus,
  String? reasonCode,
}) {
  return PlaybackSourceDto(
    episodeId: episodeId,
    sourceId: sourceId,
    hlsUrl: hlsUrl,
    backupHlsUrls: const [],
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
    durationMs: durationMs,
    width: width,
    height: height,
    aspectRatio: aspectRatio,
    codec: codec,
    cachePolicy: cachePolicy,
    preloadPolicy: preloadPolicy,
    subtitleTracks: const [],
    previewSpriteUrl: previewSpriteUrl,
    previewVttUrl: previewVttUrl,
    isAvailable: isAvailable,
    accessStatus: accessStatus,
    reasonCode: reasonCode,
  );
}

PlayerContentDto _playerContentDto({
  List<PlayerEpisodeDto> episodes = const [],
}) {
  return PlayerContentDto(
    id: 1,
    coverUrl: 'https://cdn.example.com/poster.jpg',
    title: 'Found You',
    summary: 'Remote synopsis',
    categoryIds: const [],
    tagIds: const [],
    trailerEpisodeNum: 0,
    pricePerEpisode: 0,
    isVipOnly: 0,
    status: 1,
    languageMask: 'en',
    subtitleLangs: 'en',
    playCount: 52000000,
    favoriteCount: 1200,
    episodeTotal: 52,
    onlineAt: '2024-01-01',
    episodes: episodes,
  );
}

const _contentFreeEpisode = PlayerEpisodeDto(
  id: 1,
  episodeNo: 1,
  videoName: 'ep-1.mp4',
  sourceUrl: 'https://cdn.example.com/ep-1.m3u8',
  durationSec: 60,
  status: 1,
  publishedAt: '2024-01-01',
  subtitles: [],
  isUnlocked: 1,
  isVipOnly: 0,
);

const _contentCoinEpisode = PlayerEpisodeDto(
  id: 4,
  episodeNo: 4,
  videoName: 'ep-4.mp4',
  sourceUrl: 'https://cdn.example.com/ep-4.m3u8',
  durationSec: 60,
  status: 1,
  publishedAt: '2024-01-01',
  subtitles: [],
  isUnlocked: 0,
  isVipOnly: 0,
);

const _freeEpisode = PlayerEpisodeDto(
  id: 1,
  episodeNo: 1,
  videoName: 'ep-1.mp4',
  sourceUrl: 'https://cdn.example.com/ep-1.m3u8',
  durationSec: 60,
  status: 1,
  publishedAt: '2024-01-01',
  subtitles: [],
  isUnlocked: 1,
  isVipOnly: 0,
);

const _coinEpisode = PlayerEpisodeDto(
  id: 4,
  episodeNo: 4,
  videoName: 'ep-4.mp4',
  sourceUrl: 'https://cdn.example.com/ep-4.m3u8',
  durationSec: 60,
  status: 1,
  publishedAt: '2024-01-01',
  subtitles: [],
  isUnlocked: 0,
  isVipOnly: 0,
);

const _unavailableEpisode = PlayerEpisodeDto(
  id: 9,
  episodeNo: 9,
  videoName: 'ep-9.mp4',
  sourceUrl: 'https://cdn.example.com/ep-9.m3u8',
  durationSec: 0,
  status: 0,
  publishedAt: '2024-01-01',
  subtitles: [],
  isUnlocked: 0,
  isVipOnly: 0,
);

PlayerFeedItem _feedItem({String? videoSource}) {
  final content = PlayerContent(
    id: 'found-you',
    title: 'Found You',
    playTitle: 'Found You',
    synopsis: 'Synopsis',
    viewCountLabel: '1M',
    likeCountLabel: '1K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: const [],
    recommendations: const [],
    episodeTotal: 0,
  );
  final episode = PlayerEpisode(
    id: 'ep-1',
    number: 1,
    isLocked: false,
    videoAspectRatio: 16 / 9,
    videoUrl: videoSource,
  );
  return PlayerFeedItem(
    id: 'single:found-you:ep-1',
    mode: PlayerFeedMode.singleDrama,
    content: content,
    episode: episode,
  );
}

class _FakePlayerRemoteDataSource implements PlayerRemoteDataSource {
  _FakePlayerRemoteDataSource({
    PlayerContentDto? detail,
    PlayerFeedPageDto? forYouPage,
  }) : detail = detail ?? _playerContentDto(),
       forYouPage = forYouPage ?? const PlayerFeedPageDto(items: []);

  final PlayerContentDto detail;
  final PlayerFeedPageDto forYouPage;

  @override
  Future<PlayerContentDto> fetchDramaDetail({required int dramaId}) async {
    return detail;
  }

  @override
  Future<PlayerFeedPageDto> listForYouFeed({
    int page = 1,
    int pageSize = 20,
  }) async {
    return forYouPage;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlaybackSourceRemoteDataSource
    implements PlaybackSourceRemoteDataSource {
  _FakePlaybackSourceRemoteDataSource({required this.source});

  final PlaybackSourceDto source;
  final requestedEpisodeIds = <String>[];

  @override
  Future<PlaybackSourceDto> getPlaybackSource({
    required String episodeId,
  }) async {
    requestedEpisodeIds.add(episodeId);
    return source;
  }
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.responseData});

  final Object? responseData;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
