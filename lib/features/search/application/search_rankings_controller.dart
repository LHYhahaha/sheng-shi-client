import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale_controller.dart';
import '../../../core/runtime/api_lang_provider.dart';
import '../data/search_repository_provider.dart';
import '../domain/search_rankings.dart';

enum SearchRankingType { hotSearches, hotPlays, newOnline }

class SearchRankingState {
  const SearchRankingState({this.data, this.isLoading = false, this.error});

  final SearchRanking? data;
  final bool isLoading;
  final Object? error;

  bool get isEmpty =>
      !isLoading && error == null && data?.dramas.isEmpty == true;
}

class SearchRankingsState {
  const SearchRankingsState({
    required this.hotSearches,
    required this.hotPlays,
    required this.newOnline,
  });

  const SearchRankingsState.initial()
    : hotSearches = const SearchRankingState(isLoading: true),
      hotPlays = const SearchRankingState(isLoading: true),
      newOnline = const SearchRankingState(isLoading: true);

  final SearchRankingState hotSearches;
  final SearchRankingState hotPlays;
  final SearchRankingState newOnline;

  bool get isInitialLoading =>
      hotSearches.isLoading && hotPlays.isLoading && newOnline.isLoading;

  bool get hasPageError =>
      !hotSearches.isLoading &&
      !hotPlays.isLoading &&
      !newOnline.isLoading &&
      hotSearches.error != null &&
      hotPlays.error != null &&
      newOnline.error != null;

  SearchRankingState rankingFor(SearchRankingType type) {
    return switch (type) {
      SearchRankingType.hotSearches => hotSearches,
      SearchRankingType.hotPlays => hotPlays,
      SearchRankingType.newOnline => newOnline,
    };
  }

  SearchRankingsState copyWith({
    SearchRankingState? hotSearches,
    SearchRankingState? hotPlays,
    SearchRankingState? newOnline,
  }) {
    return SearchRankingsState(
      hotSearches: hotSearches ?? this.hotSearches,
      hotPlays: hotPlays ?? this.hotPlays,
      newOnline: newOnline ?? this.newOnline,
    );
  }
}

final searchRankingsControllerProvider =
    NotifierProvider<SearchRankingsController, SearchRankingsState>(
      SearchRankingsController.new,
    );

class SearchRankingsController extends Notifier<SearchRankingsState> {
  final Map<SearchRankingType, int> _generations = {
    for (final type in SearchRankingType.values) type: 0,
  };

  @override
  SearchRankingsState build() {
    ref.listen(appLocaleControllerProvider.select(apiLangFromLocale), (
      previous,
      next,
    ) {
      if (previous == null || previous == next) {
        return;
      }
      unawaited(loadRankings());
    });
    return const SearchRankingsState.initial();
  }

  Future<void> loadRankings() async {
    await Future.wait([
      _load(SearchRankingType.hotSearches),
      _load(SearchRankingType.hotPlays),
      _load(SearchRankingType.newOnline),
    ]);
  }

  Future<void> retry(SearchRankingType type) => _load(type);

  Future<void> retryAll() => loadRankings();

  Future<void> _load(SearchRankingType type) async {
    final generation = (_generations[type] ?? 0) + 1;
    _generations[type] = generation;
    final previous = state.rankingFor(type);
    _replace(type, SearchRankingState(data: previous.data, isLoading: true));

    try {
      final repository = ref.read(searchRepositoryProvider);
      final data = switch (type) {
        SearchRankingType.hotSearches => await repository.getHotSearches(),
        SearchRankingType.hotPlays => await repository.getHotPlays(),
        SearchRankingType.newOnline => await repository.getNewOnline(),
      };
      if (_generations[type] != generation) return;
      _replace(type, SearchRankingState(data: data));
    } catch (error) {
      if (_generations[type] != generation) return;
      _replace(type, SearchRankingState(data: previous.data, error: error));
    }
  }

  void _replace(SearchRankingType type, SearchRankingState ranking) {
    state = switch (type) {
      SearchRankingType.hotSearches => state.copyWith(hotSearches: ranking),
      SearchRankingType.hotPlays => state.copyWith(hotPlays: ranking),
      SearchRankingType.newOnline => state.copyWith(newOnline: ranking),
    };
  }
}
