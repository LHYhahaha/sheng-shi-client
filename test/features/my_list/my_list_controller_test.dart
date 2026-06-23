import 'package:drama_client/features/my_list/application/my_list_controller.dart';
import 'package:drama_client/features/my_list/data/my_list_repository_provider.dart';
import 'package:drama_client/features/my_list/domain/my_list_item.dart';
import 'package:drama_client/features/my_list/domain/my_list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  });

  bool shouldThrow = false;
  final List<MyListItem> collectionItems;
  final List<MyListItem> playItems;

  @override
  Future<List<MyListItem>> fetchItems({required MyListTab tab}) async {
    if (shouldThrow) {
      throw StateError('failed');
    }

    return switch (tab) {
      MyListTab.collection => collectionItems,
      MyListTab.play => playItems,
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

const _playItemB = MyListItem(
  dramaId: 3,
  title: 'Play 2',
  introduction: 'Intro',
  coverAssetPath: 'assets/images/my_list/cover_2.png',
  currentEpisode: 2,
  episodeCount: 10,
);
