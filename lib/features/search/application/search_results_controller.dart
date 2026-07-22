import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale_controller.dart';
import '../../../core/runtime/api_lang_provider.dart';
import '../data/search_repository_provider.dart';
import '../domain/search_results.dart';

class SearchResultsState {
  const SearchResultsState({
    this.keyword = '',
    this.sortType = SearchSortType.hottest,
    this.data,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final String keyword;
  final SearchSortType sortType;
  final SearchResults? data;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasMore => data != null && data!.dramas.length < data!.total;
}

final searchResultsControllerProvider =
    NotifierProvider<SearchResultsController, SearchResultsState>(
      SearchResultsController.new,
    );

class SearchResultsController extends Notifier<SearchResultsState> {
  int _generation = 0;

  @override
  SearchResultsState build() {
    ref.listen(appLocaleControllerProvider.select(apiLangFromLocale), (
      previous,
      next,
    ) {
      if (previous == null || previous == next || state.keyword.isEmpty) {
        return;
      }
      unawaited(search(keyword: state.keyword, sortType: state.sortType));
    });
    return const SearchResultsState();
  }

  Future<void> reportSearchResultClick(String dramaId) async {
    try {
      await ref
          .read(searchRepositoryProvider)
          .reportSearchResultClick(dramaId: dramaId);
    } catch (error) {
      debugPrint(
        '[SearchResultsController] Search result click report failed for '
        '$dramaId: $error',
      );
    }
  }

  Future<void> search({
    required String keyword,
    SearchSortType sortType = SearchSortType.hottest,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) return;
    final generation = ++_generation;
    state = SearchResultsState(
      keyword: normalizedKeyword,
      sortType: sortType,
      isLoading: true,
    );
    try {
      final data = await _request(
        keyword: normalizedKeyword,
        page: 1,
        sortType: sortType,
      );
      if (generation != _generation) return;
      state = SearchResultsState(
        keyword: normalizedKeyword,
        sortType: sortType,
        data: data,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = SearchResultsState(
        keyword: normalizedKeyword,
        sortType: sortType,
        error: error,
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.data;
    if (current == null ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    state = SearchResultsState(
      keyword: state.keyword,
      sortType: state.sortType,
      data: current,
      isLoadingMore: true,
    );
    try {
      final next = await _request(
        keyword: state.keyword,
        page: current.page + 1,
        sortType: state.sortType,
      );
      state = SearchResultsState(
        keyword: state.keyword,
        sortType: state.sortType,
        data: SearchResults(
          keyword: next.keyword,
          page: next.page,
          pageSize: next.pageSize,
          total: next.total,
          dramas: [...current.dramas, ...next.dramas],
          // 猜你喜欢由首次搜索响应提供；分页加载不应替换已展示的推荐列表。
          guessLike: current.guessLike,
        ),
      );
    } catch (error) {
      state = SearchResultsState(
        keyword: state.keyword,
        sortType: state.sortType,
        data: current,
        loadMoreError: error,
      );
    }
  }

  Future<SearchResults> _request({
    required String keyword,
    required int page,
    required SearchSortType sortType,
  }) {
    return ref
        .read(searchRepositoryProvider)
        .search(
          keyword: keyword,
          page: '$page',
          pageSize: '20',
          sortType: sortType,
        );
  }
}

class SearchSuggestionsState {
  const SearchSuggestionsState({
    this.keyword = '',
    this.data,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final String keyword;
  final SearchResults? data;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasMore => data != null && data!.dramas.length < data!.total;
}

final searchSuggestionsControllerProvider =
    NotifierProvider<SearchSuggestionsController, SearchSuggestionsState>(
      SearchSuggestionsController.new,
    );

class SearchSuggestionsController extends Notifier<SearchSuggestionsState> {
  int _generation = 0;

  @override
  SearchSuggestionsState build() {
    ref.listen(appLocaleControllerProvider.select(apiLangFromLocale), (
      previous,
      next,
    ) {
      if (previous == null || previous == next || state.keyword.isEmpty) {
        return;
      }
      unawaited(search(state.keyword));
    });
    return const SearchSuggestionsState();
  }

  void clear() {
    _generation++;
    state = const SearchSuggestionsState();
  }

  Future<void> search(String keyword) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      clear();
      return;
    }
    final generation = ++_generation;
    state = SearchSuggestionsState(keyword: normalizedKeyword, isLoading: true);
    try {
      final data = await ref
          .read(searchRepositoryProvider)
          .search(keyword: normalizedKeyword, pageSize: '20');
      if (generation != _generation) return;
      state = SearchSuggestionsState(keyword: normalizedKeyword, data: data);
    } catch (error) {
      if (generation != _generation) return;
      state = SearchSuggestionsState(keyword: normalizedKeyword, error: error);
    }
  }

  Future<void> loadMore() async {
    final current = state.data;
    if (current == null ||
        state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore) {
      return;
    }
    final keyword = state.keyword;
    final generation = _generation;
    state = SearchSuggestionsState(
      keyword: keyword,
      data: current,
      isLoadingMore: true,
    );
    try {
      final next = await ref
          .read(searchRepositoryProvider)
          .search(
            keyword: keyword,
            page: '${current.page + 1}',
            pageSize: '20',
          );
      if (generation != _generation) return;
      state = SearchSuggestionsState(
        keyword: keyword,
        data: SearchResults(
          keyword: next.keyword,
          page: next.page,
          pageSize: next.pageSize,
          total: next.total,
          dramas: _mergeDramas(current.dramas, next.dramas),
          guessLike: next.guessLike,
        ),
      );
    } catch (error) {
      if (generation != _generation) return;
      state = SearchSuggestionsState(
        keyword: keyword,
        data: current,
        loadMoreError: error,
      );
    }
  }

  List<SearchResultDrama> _mergeDramas(
    List<SearchResultDrama> current,
    List<SearchResultDrama> next,
  ) {
    final seenIds = current.map((drama) => drama.id).toSet();
    return [...current, ...next.where((drama) => seenIds.add(drama.id))];
  }
}
