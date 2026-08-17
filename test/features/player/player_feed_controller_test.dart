import 'package:drama_client/features/player/application/player_feed_controller.dart';
import 'package:drama_client/features/player/data/local/player_episode_unlock_cache.dart';
import 'package:drama_client/features/player/data/player_feed_repository_provider.dart';
import 'package:drama_client/features/player/domain/player_content.dart';
import 'package:drama_client/features/player/domain/player_feed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads single drama feed from requested episode', () async {
    final container = _createContainer();
    final provider = playerFeedControllerProvider('single');
    final controller = container.read(provider.notifier);

    await controller.load(
      const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '3'),
    );
    final state = container.read(provider);

    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.items, hasLength(3));
    expect(state.items.map((item) => item.episode.number), [1, 2, 3]);
    expect(state.currentIndex, 2);
    expect(state.currentItem?.content.id, 'drama-a');
    expect(state.currentItem?.episode.number, 3);
  });

  test('loads for you feed and updates current index', () async {
    final container = _createContainer();
    final provider = playerFeedControllerProvider('for-you');
    final controller = container.read(provider.notifier);

    await controller.load(const PlayerFeedConfig.forYou());
    controller.setCurrentIndex(1);
    final state = container.read(provider);

    expect(state.items, hasLength(2));
    expect(state.currentIndex, 1);
    expect(state.currentItem?.mode, PlayerFeedMode.forYou);
    expect(state.currentItem?.content.id, 'drama-b');
  });

  test('loads more for you items and stops after the last page', () async {
    final repository = _PagedFakeFeedRepo();
    final container = _createContainer(repository);
    final provider = playerFeedControllerProvider('for-you-paged');
    final controller = container.read(provider.notifier);

    await controller.load(const PlayerFeedConfig.forYou());
    var state = container.read(provider);
    expect(state.items.map((item) => item.id), ['page-1']);
    expect(state.hasMore, isTrue);
    expect(state.nextPage, 2);

    await controller.loadMore();
    state = container.read(provider);
    expect(state.items.map((item) => item.id), ['page-1', 'page-2']);
    expect(state.hasMore, isFalse);
    expect(state.nextPage, 3);

    await controller.loadMore();
    expect(repository.requestedPages, [1, 2]);
  });

  test(
    'reuses a preloaded for you first page until explicitly refreshed',
    () async {
      final repository = _PagedFakeFeedRepo();
      final container = _createContainer(repository);
      final provider = playerFeedControllerProvider('for-you-preloaded');
      final controller = container.read(provider.notifier);
      const config = PlayerFeedConfig.forYou();

      await controller.load(config);
      await controller.load(config);

      expect(repository.requestedPages, [1]);
      expect(container.read(provider).items.map((item) => item.id), ['page-1']);

      await controller.load(config, forceRefresh: true);

      expect(repository.requestedPages, [1, 1]);
    },
  );

  test('selects episode by moving to an existing feed item', () async {
    final container = _createContainer();
    final provider = playerFeedControllerProvider('single');
    final controller = container.read(provider.notifier);

    await controller.load(
      const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '1'),
    );
    final targetIndex = controller.selectEpisode(_episode(2));
    final state = container.read(provider);

    expect(targetIndex, 1);
    expect(state.currentIndex, 1);
    expect(state.currentItem?.episode.number, 2);
  });

  test('goNext moves to next item and stops at the end', () async {
    final container = _createContainer();
    final provider = playerFeedControllerProvider('single');
    final controller = container.read(provider.notifier);

    await controller.load(
      const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '1'),
    );

    expect(container.read(provider).canGoNext, isTrue);
    controller.goNext();
    expect(container.read(provider).currentIndex, 1);

    controller.goNext();
    expect(container.read(provider).currentIndex, 2);
    expect(container.read(provider).canGoNext, isFalse);

    controller.goNext();
    expect(container.read(provider).currentIndex, 2);
  });

  test('refreshing current drama keeps requested episode index', () async {
    final container = _createContainer();
    final provider = playerFeedControllerProvider('single');
    final controller = container.read(provider.notifier);

    await controller.load(
      const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '3'),
    );

    final refreshedItem = await controller.refreshCurrentDramaAtEpisode(
      episodeId: 'ep-3',
    );
    final state = container.read(provider);

    expect(refreshedItem?.episode.number, 3);
    expect(state.items.map((item) => item.episode.number), [1, 2, 3]);
    expect(state.currentIndex, 2);
    expect(state.currentItem?.episode.number, 3);
  });

  test(
    'starting from a middle episode can move back to the previous episode',
    () async {
      final container = _createContainer();
      final provider = playerFeedControllerProvider('single');
      final controller = container.read(provider.notifier);

      await controller.load(
        const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '3'),
      );

      controller.setCurrentIndex(container.read(provider).currentIndex - 1);
      final state = container.read(provider);

      expect(state.currentIndex, 1);
      expect(state.currentItem?.episode.number, 2);
    },
  );

  test('keeps for you and single drama feed sessions isolated', () async {
    final container = _createContainer();
    final forYouProvider = playerFeedControllerProvider('for-you-tab');
    final singleProvider = playerFeedControllerProvider('single:drama-a:1');

    await container
        .read(forYouProvider.notifier)
        .load(const PlayerFeedConfig.forYou());
    container.read(forYouProvider.notifier).setCurrentIndex(1);

    await container
        .read(singleProvider.notifier)
        .load(
          const PlayerFeedConfig.singleDrama(
            dramaId: 'drama-a',
            episodeId: '3',
          ),
        );

    final forYouState = container.read(forYouProvider);
    final singleState = container.read(singleProvider);

    expect(forYouState.currentIndex, 1);
    expect(forYouState.currentItem?.mode, PlayerFeedMode.forYou);
    expect(forYouState.currentItem?.content.id, 'drama-b');
    expect(singleState.currentItem?.mode, PlayerFeedMode.singleDrama);
    expect(singleState.currentItem?.episode.number, 3);
  });

  test('keeps empty feed retryable', () async {
    final repository = _FakeFeedRepo(singleItems: const []);
    final container = _createContainer(repository);
    final provider = playerFeedControllerProvider('single-empty');
    final controller = container.read(provider.notifier);

    await controller.load(
      const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '1'),
    );
    final state = container.read(provider);

    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.items, isEmpty);
    expect(state.currentItem, isNull);
  });

  test('keeps feed error retryable', () async {
    final repository = _FakeFeedRepo()..shouldThrow = true;
    final container = _createContainer(repository);
    final provider = playerFeedControllerProvider('single-error');
    final controller = container.read(provider.notifier);

    await controller.load(
      const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '1'),
    );
    var state = container.read(provider);
    expect(state.isLoading, isFalse);
    expect(state.error, isA<StateError>());
    expect(state.items, isEmpty);

    repository.shouldThrow = false;
    await controller.retry();
    state = container.read(provider);

    expect(state.error, isNull);
    expect(state.items, isNotEmpty);
    expect(state.currentItem?.episode.number, 1);
  });

  test(
    'coin unlock marks the episode cache before detail data refreshes',
    () async {
      PlayerEpisodeUnlockCache.clearAllCache();
      addTearDown(PlayerEpisodeUnlockCache.clearAllCache);
      final container = _createContainer();
      final provider = playerFeedControllerProvider('single');
      final controller = container.read(provider.notifier);

      await controller.load(
        const PlayerFeedConfig.singleDrama(dramaId: 'drama-a', episodeId: '1'),
      );

      controller.updateEpisodeViewingEntitlementType(
        dramaId: 'drama-a',
        episodeId: 'ep-1',
        viewingEntitlementType: 'coin',
      );

      expect(
        PlayerEpisodeUnlockCache.isEpisodeUnlocked('drama-a', 'ep-1', true),
        isTrue,
      );
    },
  );
}

ProviderContainer _createContainer([PlayerFeedRepository? repository]) {
  final container = ProviderContainer(
    overrides: [
      playerFeedRepositoryProvider.overrideWithValue(
        repository ?? _FakeFeedRepo(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeFeedRepo implements PlayerFeedRepository {
  _FakeFeedRepo({this.singleItems});

  final List<PlayerFeedItem>? singleItems;
  bool shouldThrow = false;

  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
    if (shouldThrow) {
      throw StateError('failed');
    }
    if (singleItems != null) {
      return singleItems!;
    }

    final content = _content(dramaId);
    final items = content.episodes
        .map((episode) {
          return PlayerFeedItem(
            id: '$dramaId-${episode.id}',
            mode: PlayerFeedMode.singleDrama,
            content: content,
            episode: episode,
          );
        })
        .toList(growable: false);
    return items;
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
    if (shouldThrow) {
      throw StateError('failed');
    }

    return [
      PlayerFeedItem(
        id: 'a-1',
        mode: PlayerFeedMode.forYou,
        content: _content('drama-a'),
        episode: _episode(1),
      ),
      PlayerFeedItem(
        id: 'b-1',
        mode: PlayerFeedMode.forYou,
        content: _content('drama-b'),
        episode: _episode(1),
      ),
    ];
  }
}

class _PagedFakeFeedRepo extends _FakeFeedRepo
    implements PagedForYouFeedRepository {
  final List<int> requestedPages = [];

  @override
  Future<PlayerFeedPage> listForYouFeedPage({
    required int page,
    int pageSize = 20,
  }) async {
    requestedPages.add(page);
    return PlayerFeedPage(
      items: [
        PlayerFeedItem(
          id: 'page-$page',
          mode: PlayerFeedMode.forYou,
          content: _content('drama-$page'),
          episode: _episode(1),
        ),
      ],
      page: page,
      pageSize: pageSize,
      total: 2,
      hasMore: page < 2,
    );
  }
}

PlayerContent _content(String id) {
  return PlayerContent(
    id: id,
    title: 'Title $id',
    playTitle: 'Play $id',
    synopsis: 'Synopsis $id',
    viewCountLabel: '1M Views',
    likeCountLabel: '1K',
    backgroundAssetPath: 'assets/images/player/player_background.png',
    posterAssetPath: 'assets/images/player/recommend_1.png',
    episodes: [_episode(1), _episode(2), _episode(3)],
    recommendations: const [],
    episodeTotal: 3,
  );
}

PlayerEpisode _episode(int number) {
  return PlayerEpisode(
    id: 'ep-$number',
    number: number,
    isLocked: false,
    videoUrl: switch (number) {
      1 => 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      2 => 'https://test-streams.mux.dev/tos_ismc/main.m3u8',
      _ =>
        'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/gear1/prog_index.m3u8',
    },
  );
}
