import 'package:drama_client/features/my_list/application/my_list_hot_plays_controller.dart';
import 'package:drama_client/features/search/data/search_repository_provider.dart';
import 'package:drama_client/features/search/domain/search_rankings.dart';
import 'package:drama_client/features/search/domain/search_repository.dart';
import 'package:drama_client/features/search/domain/search_results.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads at most six hot plays', () async {
    final repository = _FakeSearchRepository(dramas: List.generate(8, _drama));
    final container = _createContainer(repository);

    await container.read(myListHotPlaysControllerProvider.notifier).load();
    final state = container.read(myListHotPlaysControllerProvider);

    expect(state.dramas.map((drama) => drama.id), [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
    ]);
    expect(state.shouldShow, isTrue);
    expect(repository.hotPlaysRequestCount, 1);
  });

  test('stays hidden when fewer than six hot plays load', () async {
    final repository = _FakeSearchRepository(dramas: List.generate(5, _drama));
    final container = _createContainer(repository);

    await container.read(myListHotPlaysControllerProvider.notifier).load();
    final state = container.read(myListHotPlaysControllerProvider);

    expect(state.dramas, hasLength(5));
    expect(state.shouldShow, isFalse);
  });

  test('stays hidden when hot-play data is empty', () async {
    final container = _createContainer(_FakeSearchRepository());

    await container.read(myListHotPlaysControllerProvider.notifier).load();

    expect(
      container.read(myListHotPlaysControllerProvider).shouldShow,
      isFalse,
    );
  });

  test(
    'stays hidden when the hot-play request fails without cached data',
    () async {
      final container = _createContainer(
        _FakeSearchRepository(shouldThrow: true),
      );

      await container.read(myListHotPlaysControllerProvider.notifier).load();
      final state = container.read(myListHotPlaysControllerProvider);

      expect(state.shouldShow, isFalse);
      expect(state.error, isA<StateError>());
    },
  );
}

ProviderContainer _createContainer(_FakeSearchRepository repository) {
  final container = ProviderContainer(
    overrides: [searchRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

SearchRankDrama _drama(int index) {
  return SearchRankDrama(
    id: '$index',
    sort: index + 1,
    coverUrl: 'https://example.com/$index.jpg',
    title: 'Drama $index',
    summary: '',
    tags: const ['Young Adult'],
    searchCount: 100,
    trailerEpisodeNum: 1,
    isVipOnly: false,
    status: 1,
  );
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.dramas = const [], this.shouldThrow = false});

  final List<SearchRankDrama> dramas;
  final bool shouldThrow;
  int hotPlaysRequestCount = 0;

  @override
  Future<void> reportSearchResultClick({required String dramaId}) async {}

  @override
  Future<SearchRanking> getHotPlays() async {
    hotPlaysRequestCount += 1;
    if (shouldThrow) {
      throw StateError('hot plays failed');
    }
    return SearchRanking(limit: dramas.length, dramas: dramas);
  }

  @override
  Future<SearchRanking> getHotSearches() => throw UnimplementedError();

  @override
  Future<SearchRanking> getNewOnline() => throw UnimplementedError();

  @override
  Future<SearchRankings> getRankings() => throw UnimplementedError();

  @override
  Future<SearchResults> search({
    required String keyword,
    String page = '1',
    String pageSize = '20',
    SearchSortType? sortType,
  }) => throw UnimplementedError();
}
