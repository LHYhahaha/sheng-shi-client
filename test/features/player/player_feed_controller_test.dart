import 'package:drama_client/features/player/application/player_feed_controller.dart';
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
}

ProviderContainer _createContainer() {
  final container = ProviderContainer(
    overrides: [
      playerFeedRepositoryProvider.overrideWithValue(_FakeFeedRepo()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeFeedRepo implements PlayerFeedRepository {
  @override
  Future<List<PlayerFeedItem>> listSingleDramaFeed({
    required String dramaId,
    required String episodeId,
  }) async {
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
    final index = items.indexWhere((item) => item.episode.number == 3);
    return episodeId == '3'
        ? [...items.sublist(index), ...items.sublist(0, index)]
        : items;
  }

  @override
  Future<List<PlayerFeedItem>> listForYouFeed() async {
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
  );
}

PlayerEpisode _episode(int number) {
  return PlayerEpisode(id: 'ep-$number', number: number, isLocked: false);
}
