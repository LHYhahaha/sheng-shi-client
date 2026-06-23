import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale_controller.dart';
import '../../../core/runtime/api_lang_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../data/home_repository_provider.dart';
import '../domain/home_data.dart';

class HomeDataState {
  const HomeDataState({
    this.data,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final HomeData? data;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? loadMoreError;

  bool get hasError => error != null;

  HomeDataState copyWith({
    HomeData? data,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return HomeDataState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }
}

final homeDataControllerProvider =
    NotifierProvider<HomeDataController, HomeDataState>(HomeDataController.new);

class HomeDataController extends Notifier<HomeDataState> {
  static const pageSize = 20;

  bool _loadAttempted = false;
  int _generation = 0;

  @override
  HomeDataState build() {
    ref.listen(appLocaleControllerProvider, (previous, next) {
      final previousLang = previous == null ? null : apiLangFromLocale(previous);
      final nextLang = apiLangFromLocale(next);
      if (previousLang == nextLang) {
        return;
      }
      if (!_loadAttempted && state.data == null) {
        return;
      }

      _loadAttempted = true;
      unawaited(loadHomeData());
    });

    ref.listen(authControllerProvider, (previous, next) {
      final wasReady = previous != null && !previous.isLoading;
      final isReady = !next.isLoading && next.error == null;

      if (!wasReady && isReady && !_loadAttempted) {
        _loadAttempted = true;
        unawaited(Future.microtask(loadHomeData));
      }
    });

    Future.microtask(() {
      final authState = ref.read(authControllerProvider);
      if (!authState.isLoading && authState.error == null && !_loadAttempted) {
        _loadAttempted = true;
        unawaited(loadHomeData());
      }
    });

    return const HomeDataState();
  }

  Future<void> loadHomeData() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final repository = ref.read(homeRepositoryProvider);
      final homeData = await repository.getHomeData();
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        data: homeData,
        isLoading: false,
        clearError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> refreshTab(int tabId) async {
    final currentData = state.data;
    if (currentData == null) {
      await loadHomeData();
      return;
    }

    final generation = ++_generation;
    state = state.copyWith(clearError: true, clearLoadMoreError: true);

    try {
      final repository = ref.read(homeRepositoryProvider);
      final page = await repository.getHomeData(
        page: 1,
        pageSize: pageSize,
        tabId: tabId,
      );
      if (!_isCurrent(generation)) {
        return;
      }

      final tab = _tabFromPage(page, tabId);
      state = state.copyWith(
        data: _replaceTab(currentData, tab),
        clearError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(error: error);
    }
  }

  Future<void> refreshHomeData() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final repository = ref.read(homeRepositoryProvider);
      final homeData = await repository.getHomeData();
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        data: homeData,
        isLoadingMore: false,
        clearError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(error: error, isLoadingMore: false);
    }
  }

  Future<void> loadMoreTab(int tabId) async {
    final currentData = state.data;
    if (currentData == null || state.isLoadingMore) {
      return;
    }

    final tab = _findTab(currentData, tabId);
    if (tab == null || !tab.hasMoreDramas) {
      return;
    }

    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final repository = ref.read(homeRepositoryProvider);
      final page = await repository.getHomeData(
        page: tab.nextPage,
        pageSize: pageSize,
        tabId: tabId,
      );
      if (!_isCurrent(generation)) {
        return;
      }

      final nextTab = _tabFromPage(page, tabId);
      final mergedTab = nextTab.copyWith(
        dramas: List.unmodifiable([...tab.dramas, ...nextTab.dramas]),
      );
      state = state.copyWith(
        data: _replaceTab(currentData, mergedTab),
        isLoadingMore: false,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(loadMoreError: error, isLoadingMore: false);
    }
  }

  Future<void> retry() async {
    _loadAttempted = true;
    await loadHomeData();
  }

  HomeTab? _findTab(HomeData data, int tabId) {
    for (final tab in data.tabs) {
      if (tab.id == tabId) {
        return tab;
      }
    }
    return null;
  }

  HomeTab _tabFromPage(HomeData page, int tabId) {
    final matchingTab = _findTab(page, tabId);
    if (matchingTab != null) {
      return matchingTab;
    }
    if (page.tabs.isNotEmpty) {
      return page.tabs.first;
    }
    throw StateError('Home tab $tabId not found in response');
  }

  HomeData _replaceTab(HomeData currentData, HomeTab tab) {
    var replaced = false;
    final tabs = [
      for (final existing in currentData.tabs)
        if (existing.id == tab.id) ...[tab] else ...[existing],
    ];

    for (final existing in currentData.tabs) {
      if (existing.id == tab.id) {
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      tabs.add(tab);
    }

    return currentData.copyWith(tabs: List.unmodifiable(tabs));
  }

  bool _isCurrent(int generation) {
    return generation == _generation;
  }
}
