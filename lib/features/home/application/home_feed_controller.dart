import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drama/data/drama_repository_provider.dart';
import '../../drama/domain/drama.dart';

final homeFeedControllerProvider =
    NotifierProvider<HomeFeedController, HomeFeedState>(HomeFeedController.new);

class HomeFeedState {
  const HomeFeedState({
    required this.categories,
    required this.items,
    required this.selectedIndex,
    required this.nextPageToken,
    required this.isInitialLoading,
    required this.isLoadingMore,
    this.initialError,
    this.loadMoreError,
  });

  const HomeFeedState.initial()
    : categories = const [],
      items = const [],
      selectedIndex = 0,
      nextPageToken = null,
      isInitialLoading = true,
      isLoadingMore = false,
      initialError = null,
      loadMoreError = null;

  final List<DramaCategory> categories;
  final List<Drama> items;
  final int selectedIndex;
  final String? nextPageToken;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final Object? initialError;
  final Object? loadMoreError;

  bool get canLoadMore => nextPageToken != null && !isLoadingMore;

  DramaCategory? get selectedCategory {
    if (categories.isEmpty || selectedIndex >= categories.length) {
      return null;
    }

    return categories[selectedIndex];
  }

  HomeFeedState copyWith({
    List<DramaCategory>? categories,
    List<Drama>? items,
    int? selectedIndex,
    String? nextPageToken,
    bool clearNextPageToken = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    Object? initialError,
    bool clearInitialError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return HomeFeedState(
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      nextPageToken: clearNextPageToken
          ? null
          : nextPageToken ?? this.nextPageToken,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      initialError: clearInitialError
          ? null
          : initialError ?? this.initialError,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

class HomeFeedController extends Notifier<HomeFeedState> {
  int _generation = 0;

  @override
  HomeFeedState build() => const HomeFeedState.initial();

  Future<void> loadInitial({String? preferredCategoryId}) async {
    final generation = ++_generation;
    state = state.copyWith(
      items: const [],
      isInitialLoading: true,
      isLoadingMore: false,
      clearInitialError: true,
      clearLoadMoreError: true,
      clearNextPageToken: true,
    );

    try {
      final repository = ref.read(dramaRepositoryProvider);
      final categories = await repository.listHomeCategories();
      if (!_isCurrent(generation)) {
        return;
      }

      if (categories.isEmpty) {
        state = state.copyWith(
          categories: const [],
          selectedIndex: 0,
          isInitialLoading: false,
        );
        return;
      }

      final selectedIndex = _resolveSelectedIndex(
        categories,
        preferredCategoryId,
      );
      final page = await repository.listHomeFeed(
        categoryId: categories[selectedIndex].id,
      );
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        categories: List<DramaCategory>.unmodifiable(categories),
        selectedIndex: selectedIndex,
        items: List<Drama>.unmodifiable(page.items),
        nextPageToken: page.nextPageToken,
        clearNextPageToken: page.nextPageToken == null,
        isInitialLoading: false,
        clearInitialError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        initialError: error,
        isInitialLoading: false,
        clearNextPageToken: true,
      );
    }
  }

  Future<void> selectCategory(int index) async {
    if (index == state.selectedIndex || index >= state.categories.length) {
      return;
    }

    final categoryId = state.categories[index].id;
    state = state.copyWith(selectedIndex: index);
    await loadInitial(preferredCategoryId: categoryId);
  }

  Future<void> loadMore() async {
    final pageToken = state.nextPageToken;
    final selectedCategory = state.selectedCategory;
    if (pageToken == null || selectedCategory == null || state.isLoadingMore) {
      return;
    }

    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final page = await ref
          .read(dramaRepositoryProvider)
          .listHomeFeed(categoryId: selectedCategory.id, pageToken: pageToken);
      if (!_isCurrent(generation) ||
          state.selectedCategory?.id != selectedCategory.id) {
        return;
      }

      state = state.copyWith(
        items: List<Drama>.unmodifiable([...state.items, ...page.items]),
        nextPageToken: page.nextPageToken,
        clearNextPageToken: page.nextPageToken == null,
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

  int _resolveSelectedIndex(
    List<DramaCategory> categories,
    String? preferredCategoryId,
  ) {
    final index = categories.indexWhere(
      (category) => category.id == preferredCategoryId,
    );
    return index == -1 ? 0 : index;
  }

  bool _isCurrent(int generation) {
    return generation == _generation;
  }
}
