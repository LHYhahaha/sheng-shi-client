import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/features/entitlement/domain/episode_unlock_type.dart';
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
      _detailDto(episodes: [_coinEpisode]),
    );

    expect(content.id, 'found-you');
    expect(content.title, 'Found You');
    expect(content.synopsis, 'Remote synopsis');
    expect(content.viewCountLabel, '12.4M Views');
    expect(content.episodes, hasLength(1));
    expect(content.episodes.single.id, 'ep-4');
    expect(content.episodes.single.unlockType, EpisodeUnlockType.coins);
    expect(content.episodes.single.requiredCoins, 30);
    expect(content.episodes.single.isLocked, isTrue);
    expect(content.episodes.single.videoAspectRatio, 16 / 9);
  });

  test('unavailable episode dto maps to unavailable domain episode', () {
    final episode = contentMapper.mapEpisode(_unavailableEpisode);

    expect(episode.isUnavailable, isTrue);
    expect(episode.isAvailable, isFalse);
  });

  test('playback source dto maps cache key with sourceId and expiry', () {
    final item = _feedItem();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));
    final source = sourceMapper.mapSource(
      PlaybackSourceDto(
        episodeId: 'ep-1',
        sourceId: 'source-a',
        hlsUrl: 'https://cdn.example.com/a.m3u8',
        backupHlsUrls: const [],
        expiresAt: expiresAt,
        durationMs: 60000,
        width: 1080,
        height: 1920,
        aspectRatio: 9 / 16,
        codec: 'hls',
        cachePolicy: const {'ttl': 300},
        preloadPolicy: const {'level': 'playlist'},
        subtitleTracks: const [],
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

  test('missing hlsUrl throws instead of creating invalid source', () {
    final item = _feedItem();

    expect(
      () => sourceMapper.mapSource(
        const PlaybackSourceDto(
          episodeId: 'ep-1',
          sourceId: 'source-a',
          hlsUrl: null,
          backupHlsUrls: [],
          expiresAt: null,
          durationMs: null,
          width: null,
          height: null,
          aspectRatio: null,
          codec: null,
          cachePolicy: {},
          preloadPolicy: {},
          subtitleTracks: [],
          previewSpriteUrl: null,
          previewVttUrl: null,
        ),
        item: item,
        status: PlaybackSourceStatus.resolved,
      ),
      throwsStateError,
    );
  });

  test('expired playback source remains visible to playback layer', () {
    final item = _feedItem();
    final expiredAt = DateTime.now().subtract(const Duration(minutes: 1));
    final source = sourceMapper.mapSource(
      PlaybackSourceDto(
        episodeId: 'ep-1',
        sourceId: 'expired-source',
        hlsUrl: 'https://cdn.example.com/expired.m3u8',
        backupHlsUrls: const [],
        expiresAt: expiredAt,
        durationMs: null,
        width: null,
        height: null,
        aspectRatio: null,
        codec: null,
        cachePolicy: const {},
        preloadPolicy: const {},
        subtitleTracks: const [],
        previewSpriteUrl: null,
        previewVttUrl: null,
      ),
      item: item,
      status: PlaybackSourceStatus.resolved,
    );

    expect(source.expiresAt.isBefore(DateTime.now()), isTrue);
  });

  test('remote content repository combines detail and episode list', () async {
    final repository = RemotePlayerContentRepository(
      remoteDataSource: _FakePlayerRemoteDataSource(
        detail: _detailDto(),
        episodes: [_freeEpisode, _coinEpisode],
      ),
    );

    final content = await repository.getPlayerContent(dramaId: 'found-you');

    expect(content.id, 'found-you');
    expect(content.episodes.map((episode) => episode.id), ['ep-1', 'ep-4']);
  });

  test(
    'remote feed repository maps single drama feed with stable ids',
    () async {
      final repository = RemotePlayerFeedRepository(
        remoteDataSource: _FakePlayerRemoteDataSource(
          detail: _detailDto(),
          episodes: [_freeEpisode, _coinEpisode],
        ),
      );

      final items = await repository.listSingleDramaFeed(
        dramaId: 'found-you',
        episodeId: '4',
      );

      expect(items.first.id, 'single:found-you:ep-4');
      expect(items.first.episode.number, 4);
      expect(items.last.id, 'single:found-you:ep-1');
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
              drama: _detailDto(),
              episode: _freeEpisode,
            ),
          ],
          nextPageToken: 'next',
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
          source: const PlaybackSourceDto(
            episodeId: 'ep-1',
            sourceId: 'source-a',
            hlsUrl: 'https://cdn.example.com/a.m3u8',
            backupHlsUrls: [],
            expiresAt: null,
            durationMs: null,
            width: null,
            height: null,
            aspectRatio: null,
            codec: 'hls',
            cachePolicy: {},
            preloadPolicy: {},
            subtitleTracks: [],
            previewSpriteUrl: null,
            previewVttUrl: null,
          ),
        ),
        preloadManager: preloadManager,
      );
      final item = _feedItem();

      final resolved = await repository.resolve(item);
      final preloaded = await repository.preload(item);

      expect(resolved.remoteUrl, 'https://cdn.example.com/a.m3u8');
      expect(preloaded.status, PlaybackPreloadStatus.success);
      expect(preloadManager.preloadCount, 1);
    },
  );

  test('player providers default to mock repositories', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(playerContentRepositoryProvider),
      isA<MockPlayerContentRepository>(),
    );
    expect(
      container.read(playerFeedRepositoryProvider),
      isA<MockPlayerFeedRepository>(),
    );
    expect(
      container.read(playerPlaybackSourceRepositoryProvider),
      isA<MockPlayerPlaybackSourceRepository>(),
    );
  });

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

PlayerContentDto _detailDto({List<PlayerEpisodeDto> episodes = const []}) {
  return PlayerContentDto(
    dramaId: 'found-you',
    title: 'Found You',
    description: 'Remote synopsis',
    posterUrl: 'https://cdn.example.com/poster.jpg',
    backgroundUrl: 'https://cdn.example.com/background.jpg',
    totalEpisodes: 52,
    tags: const ['Rebirth'],
    viewCount: 12400000,
    viewCountLabel: '12.4M Views',
    likeCountLabel: '43.2K',
    episodes: episodes,
  );
}

const _freeEpisode = PlayerEpisodeDto(
  episodeId: 'ep-1',
  dramaId: 'found-you',
  episodeNumber: 1,
  title: 'EP.01',
  unlockType: 'free',
  requiredCoins: null,
  isAvailable: true,
  durationMs: 60000,
  aspectRatio: 16 / 9,
  posterUrl: null,
  previewImageUrl: null,
);

const _coinEpisode = PlayerEpisodeDto(
  episodeId: 'ep-4',
  dramaId: 'found-you',
  episodeNumber: 4,
  title: 'EP.04',
  unlockType: 'coins',
  requiredCoins: 30,
  isAvailable: true,
  durationMs: 60000,
  aspectRatio: 16 / 9,
  posterUrl: null,
  previewImageUrl: null,
);

const _unavailableEpisode = PlayerEpisodeDto(
  episodeId: 'ep-9',
  dramaId: 'found-you',
  episodeNumber: 9,
  title: 'EP.09',
  unlockType: 'free',
  requiredCoins: null,
  isAvailable: false,
  durationMs: null,
  aspectRatio: null,
  posterUrl: null,
  previewImageUrl: null,
);

PlayerFeedItem _feedItem() {
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
  );
  final episode = PlayerEpisode(
    id: 'ep-1',
    number: 1,
    isLocked: false,
    videoAspectRatio: 16 / 9,
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
    List<PlayerEpisodeDto>? episodes,
    PlayerFeedPageDto? forYouPage,
  }) : detail = detail ?? _detailDto(),
       episodes = episodes ?? const <PlayerEpisodeDto>[],
       forYouPage =
           forYouPage ??
           const PlayerFeedPageDto(items: [], nextPageToken: null);

  final PlayerContentDto detail;
  final List<PlayerEpisodeDto> episodes;
  final PlayerFeedPageDto forYouPage;

  @override
  Future<PlayerContentDto> getDramaDetail({required String dramaId}) async {
    return detail;
  }

  @override
  Future<List<PlayerEpisodeDto>> listEpisodes({required String dramaId}) async {
    return episodes;
  }

  @override
  Future<PlayerFeedPageDto> listForYouFeed({String? pageToken}) async {
    return forYouPage;
  }
}

class _FakePlaybackSourceRemoteDataSource
    implements PlaybackSourceRemoteDataSource {
  _FakePlaybackSourceRemoteDataSource({required this.source});

  final PlaybackSourceDto source;

  @override
  Future<PlaybackSourceDto> getPlaybackSource({
    required String episodeId,
  }) async {
    return source;
  }
}
