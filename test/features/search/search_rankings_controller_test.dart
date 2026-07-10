import 'package:drama_client/features/search/application/search_rankings_controller.dart';
import 'package:drama_client/features/search/data/search_repository_provider.dart';
import 'package:drama_client/features/search/domain/search_rankings.dart';
import 'package:drama_client/features/search/domain/search_repository.dart';
import 'package:drama_client/features/search/domain/search_results.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps successful rankings when one ranking request fails', () async {
    final container = ProviderContainer(
      overrides: [
        searchRepositoryProvider.overrideWithValue(
          _FakeSearchRepository(failingType: SearchRankingType.hotPlays),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(searchRankingsControllerProvider.notifier)
        .loadRankings();
    await _flushMicrotasks();

    final state = container.read(searchRankingsControllerProvider);
    expect(state.hotSearches.data?.dramas.single.title, 'hot searches');
    expect(state.hotPlays.error, isA<StateError>());
    expect(state.newOnline.data?.dramas.single.title, 'new online');
    expect(state.hasPageError, isFalse);
  });

  test('reports page error only when every ranking request fails', () async {
    final container = ProviderContainer(
      overrides: [
        searchRepositoryProvider.overrideWithValue(
          _FakeSearchRepository(failAll: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(searchRankingsControllerProvider.notifier)
        .loadRankings();
    await _flushMicrotasks();

    expect(
      container.read(searchRankingsControllerProvider).hasPageError,
      isTrue,
    );
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.failingType, this.failAll = false});

  final SearchRankingType? failingType;
  final bool failAll;

  @override
  Future<SearchRanking> getHotSearches() {
    return _result(SearchRankingType.hotSearches, 'hot searches');
  }

  @override
  Future<SearchRanking> getHotPlays() {
    return _result(SearchRankingType.hotPlays, 'hot plays');
  }

  @override
  Future<SearchRanking> getNewOnline() {
    return _result(SearchRankingType.newOnline, 'new online');
  }

  Future<SearchRanking> _result(SearchRankingType type, String title) async {
    if (failAll || failingType == type) {
      throw StateError('$type failed');
    }
    return SearchRanking(
      limit: 10,
      dramas: [
        SearchRankDrama(
          id: type.index.toString(),
          sort: 1,
          coverUrl: '',
          title: title,
          summary: '',
          tags: const [],
          searchCount: 1,
          trailerEpisodeNum: 1,
          isVipOnly: false,
          status: 1,
        ),
      ],
    );
  }

  @override
  Future<SearchRankings> getRankings() async {
    return SearchRankings(
      hotSearches: await getHotSearches(),
      hotPlays: await getHotPlays(),
      newOnline: await getNewOnline(),
    );
  }

  @override
  Future<SearchResults> search({
    required String keyword,
    String page = '1',
    String pageSize = '20',
    SearchSortType? sortType,
  }) {
    throw UnimplementedError();
  }
}
