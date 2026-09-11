import 'package:drama_client/core/auth/user_info_store.dart';
import 'package:drama_client/core/user_library/user_library_sync_controller.dart';
import 'package:drama_client/features/my_list/application/my_list_controller.dart';
import 'package:drama_client/features/my_list/data/my_list_repository_provider.dart';
import 'package:drama_client/features/my_list/domain/my_list_item.dart';
import 'package:drama_client/features/my_list/domain/my_list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'account switch removes previous unfollow override from server list',
    () async {
      final container = _createContainer(_FakeMyListRepository());
      final user = container.read(userInfoStoreProvider.notifier);
      await user.waitForHydration();
      await user.saveFromMap({'userId': 'guest'});
      final controller = container.read(myListControllerProvider.notifier);
      await controller.load();
      container
          .read(userLibrarySyncControllerProvider.notifier)
          .setFavorite(dramaId: '1', isFavorited: false);
      expect(container.read(myListControllerProvider).items, isEmpty);
      await user.saveFromMap({'userId': 'facebook'});
      expect(container.read(myListControllerProvider).items, isEmpty);
      await controller.load();
      expect(
        container.read(myListControllerProvider).items.map((e) => e.dramaId),
        [1],
      );
      expect(
        container.read(userLibrarySyncControllerProvider).favoriteFor('1'),
        isNull,
      );
    },
  );

  test('loads collection items by default', () async {
    final repository = _FakeMyListRepository();
    final container = _createContainer(repository);

    await container.read(myListControllerProvider.notifier).load();
    final state = container.read(myListControllerProvider);

    expect(state.selectedTab, MyListTab.collection);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    expect(state.items.map((item) => item.dramaId), [1]);
  });

  test(
    'silent refresh preserves state when the server data is unchanged',
    () async {
      final repository = _FakeMyListRepository();
      final container = _createContainer(repository);
      final controller = container.read(myListControllerProvider.notifier);

      await controller.load();
      final before = container.read(myListControllerProvider);

      await controller.refreshSilently();

      expect(
        identical(container.read(myListControllerProvider), before),
        isTrue,
      );
    },
  );

  test('switches tabs and reloads play items', () async {
    final repository = _FakeMyListRepository();
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    controller.enterCollectionEdit();
    controller.toggleSelection(1);

    await controller.selectTab(MyListTab.play);
    final state = container.read(myListControllerProvider);

    expect(state.selectedTab, MyListTab.play);
    expect(state.isCollectionEditing, isFalse);
    expect(state.selectedIds, isEmpty);
    expect(state.items.map((item) => item.dramaId), [2, 3]);
  });

  test('deletes selected collection items', () async {
    final repository = _FakeMyListRepository();
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    controller.enterCollectionEdit();
    controller.toggleSelection(1);
    controller.deleteSelected();
    final state = container.read(myListControllerProvider);

    expect(state.items, isEmpty);
    expect(state.selectedIds, isEmpty);
    expect(state.isCollectionEditing, isFalse);
  });

  test('deleting all selected collection items enters empty state', () async {
    final repository = _FakeMyListRepository(
      collectionItems: const [_collectionItem, _collectionItemB],
    );
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    controller.enterCollectionEdit();
    controller.toggleSelection(1);
    controller.toggleSelection(2);
    controller.deleteSelected();
    final state = container.read(myListControllerProvider);

    expect(state.items, isEmpty);
    expect(state.isEmpty, isTrue);
    expect(state.isCollectionEditing, isFalse);
  });

  test('toggles all loaded items in edit mode', () async {
    final repository = _FakeMyListRepository(
      collectionItems: const [_collectionItem, _collectionItemB],
    );
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    controller.enterCollectionEdit();
    controller.toggleSelectAll();
    var state = container.read(myListControllerProvider);

    expect(state.selectedIds, {1, 2});
    expect(state.areAllItemsSelected, isTrue);

    controller.toggleSelectAll();
    state = container.read(myListControllerProvider);

    expect(state.selectedIds, isEmpty);
    expect(state.areAllItemsSelected, isFalse);
  });

  test('deletes one play item and clears open state', () async {
    final repository = _FakeMyListRepository();
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.selectTab(MyListTab.play);
    controller.openPlayItem(2);
    controller.deleteItem(2);
    final state = container.read(myListControllerProvider);

    expect(state.openPlayItemId, isNull);
    expect(state.items.map((item) => item.dramaId), [3]);
  });

  test('deleting last play item enters empty state', () async {
    final repository = _FakeMyListRepository(playItems: const [_playItemA]);
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.selectTab(MyListTab.play);
    controller.deleteItem(2);
    final state = container.read(myListControllerProvider);

    expect(state.selectedTab, MyListTab.play);
    expect(state.items, isEmpty);
    expect(state.isEmpty, isTrue);
  });

  test('keeps error state retryable', () async {
    final repository = _FakeMyListRepository()..shouldThrow = true;
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    var state = container.read(myListControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isA<StateError>());
    expect(state.items, isEmpty);

    repository.shouldThrow = false;
    await controller.retry();
    state = container.read(myListControllerProvider);

    expect(state.error, isNull);
    expect(state.items.map((item) => item.dramaId), [1]);
  });

  test('loads next page when available', () async {
    final repository = _FakeMyListRepository(
      collectionPages: const [
        MyListPage(items: [_collectionItem], nextPageToken: '2'),
        MyListPage(items: [_collectionItemB], nextPageToken: null),
      ],
    );
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    var state = container.read(myListControllerProvider);
    expect(state.items.map((item) => item.dramaId), [1]);
    expect(state.nextPageToken, '2');

    await controller.loadMore();
    state = container.read(myListControllerProvider);

    expect(state.items.map((item) => item.dramaId), [1, 2]);
    expect(state.nextPageToken, isNull);
    expect(state.isLoadingMore, isFalse);
  });

  test(
    'does not load next page from controller after deleting one item',
    () async {
      final repository = _FakeMyListRepository(
        collectionPages: const [
          MyListPage(items: [_collectionItem], nextPageToken: '2'),
          MyListPage(items: [_collectionItemB], nextPageToken: null),
        ],
      );
      final container = _createContainer(repository);
      final controller = container.read(myListControllerProvider.notifier);

      await controller.load();
      await controller.deleteItem(1);
      final state = container.read(myListControllerProvider);

      expect(state.items, isEmpty);
      expect(state.nextPageToken, '2');
      expect(repository.fetchPageTokens, [null]);
    },
  );

  test(
    'does not load next page from controller after deleting selected items',
    () async {
      final repository = _FakeMyListRepository(
        collectionPages: const [
          MyListPage(
            items: [_collectionItem, _collectionItemB],
            nextPageToken: '2',
          ),
          MyListPage(items: [_collectionItemC], nextPageToken: null),
        ],
      );
      final container = _createContainer(repository);
      final controller = container.read(myListControllerProvider.notifier);

      await controller.load();
      controller.enterCollectionEdit();
      controller.toggleSelection(1);
      controller.toggleSelection(2);
      await controller.deleteSelected();
      final state = container.read(myListControllerProvider);

      expect(state.items, isEmpty);
      expect(state.nextPageToken, '2');
      expect(repository.fetchPageTokens, [null]);
    },
  );

  test('refreshes current tab in place without full-page loading', () async {
    final pages = [
      MyListPage(items: [_collectionItem], nextPageToken: '2'),
      MyListPage(items: [_collectionItemB], nextPageToken: null),
    ];
    final repository = _FakeMyListRepository(collectionPages: pages);
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    await controller.loadMore();

    pages[0] = MyListPage(items: [_collectionItemUpdated], nextPageToken: '2');
    await controller.refreshCurrentTabInPlace();

    final state = container.read(myListControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.items.map((item) => item.title), [
      'Collection 1 updated',
      'Collection 2',
    ]);
    expect(state.nextPageToken, isNull);
  });

  test('refreshing after delete reads the shifted first page', () async {
    final pages = [
      MyListPage(
        items: [_collectionItem, _collectionItemB],
        nextPageToken: '2',
      ),
      MyListPage(items: [_collectionItemC], nextPageToken: null),
    ];
    final repository = _FakeMyListRepository(collectionPages: pages);
    final container = _createContainer(repository);
    final controller = container.read(myListControllerProvider.notifier);

    await controller.load();
    await controller.deleteItem(1);
    pages[0] = const MyListPage(
      items: [_collectionItemB, _collectionItemC],
      nextPageToken: null,
    );
    await controller.refreshCurrentTabInPlace();

    final state = container.read(myListControllerProvider);
    expect(state.items.map((item) => item.dramaId), [2, 4]);
    expect(state.nextPageToken, isNull);
    expect(repository.fetchPageTokens, [null, null]);
  });
}

ProviderContainer _createContainer(MyListRepository repository) {
  final container = ProviderContainer(
    overrides: [myListRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeMyListRepository implements MyListRepository {
  _FakeMyListRepository({
    this.collectionItems = const [_collectionItem],
    this.playItems = const [_playItemA, _playItemB],
    this.collectionPages,
    this.playPages,
  });

  bool shouldThrow = false;
  final List<MyListItem> collectionItems;
  final List<MyListItem> playItems;
  final List<MyListPage>? collectionPages;
  final List<MyListPage>? playPages;
  final fetchPageTokens = <String?>[];

  @override
  Future<List<MyListItem>> fetchItems({required MyListTab tab}) async {
    final page = await fetchPage(tab: tab);
    return page.items;
  }

  @override
  Future<MyListPage> fetchPage({
    required MyListTab tab,
    String? pageToken,
  }) async {
    if (shouldThrow) {
      throw StateError('failed');
    }

    fetchPageTokens.add(pageToken);
    final pageIndex = (int.tryParse(pageToken ?? '1') ?? 1) - 1;
    return switch (tab) {
      MyListTab.collection =>
        collectionPages != null
            ? collectionPages![pageIndex]
            : MyListPage(items: collectionItems, nextPageToken: null),
      MyListTab.play =>
        playPages != null
            ? playPages![pageIndex]
            : MyListPage(items: playItems, nextPageToken: null),
    };
  }

  @override
  Future<void> deleteFavorite({required int dramaId}) async {}

  @override
  Future<void> deleteFavorites({required List<int> dramaIds}) async {}

  @override
  Future<void> deletePlayHistory({required int historyId}) async {}

  @override
  Future<void> deletePlayHistories({required List<int> historyIds}) async {}
}

const _collectionItem = MyListItem(
  dramaId: 1,
  title: 'Collection 1',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_1.png',
  currentEpisode: 1,
  episodeCount: 10,
);

const _collectionItemUpdated = MyListItem(
  dramaId: 1,
  title: 'Collection 1 updated',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_1.png',
  currentEpisode: 2,
  episodeCount: 10,
);

const _playItemA = MyListItem(
  dramaId: 2,
  title: 'Play 1',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_1.png',
  currentEpisode: 1,
  episodeCount: 10,
);

const _collectionItemB = MyListItem(
  dramaId: 2,
  title: 'Collection 2',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_2.png',
  currentEpisode: 2,
  episodeCount: 10,
);

const _collectionItemC = MyListItem(
  dramaId: 4,
  title: 'Collection 3',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_3.png',
  currentEpisode: 3,
  episodeCount: 10,
);

const _playItemB = MyListItem(
  dramaId: 3,
  title: 'Play 2',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_2.png',
  currentEpisode: 2,
  episodeCount: 10,
);
