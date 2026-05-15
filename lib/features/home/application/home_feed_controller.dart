import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../drama/data/drama_repository_provider.dart';
import '../../drama/domain/drama.dart';

final homeFeedControllerProvider =
    NotifierProvider<HomeFeedController, HomeFeedState>(HomeFeedController.new);

/// 首页 feed 状态。
///
/// initial loading/error 和 load-more loading/error 分开存，是为了让首屏失败显示整页
/// retry，而分页失败只影响底部 footer。不要合并成一个 error，否则分页失败会清空
/// 已经加载的首页内容。
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

  /// 首页分类列表。
  ///
  /// 分类是分页请求的上游条件。切分类时必须重新加载第一页，不能只本地过滤旧 items。
  final List<DramaCategory> categories;

  /// 当前分类下的剧卡列表。
  ///
  /// 只包含 Home 展示信息，不包含 episode source。点击后仍要进入 Player feed 链路。
  final List<Drama> items;

  /// 当前选中分类的索引。
  ///
  /// 使用索引是为了驱动 tab UI；真实请求仍使用 categories[selectedIndex].id，避免
  /// 展示标题变化影响分页。
  final int selectedIndex;

  /// 当前分类下一页游标。
  ///
  /// null 表示没有更多。不要用 items.length 或 pageSize 推断分页结束。
  final String? nextPageToken;

  /// 首屏分类和第一页是否加载中。
  ///
  /// 该状态会显示整页 loading，并清理分页状态。
  final bool isInitialLoading;

  /// 是否正在追加下一页。
  ///
  /// 该状态只影响底部 footer，不能清空已加载 items。
  final bool isLoadingMore;

  /// 首屏加载错误。
  ///
  /// 用于整页 retry。分页错误不能写到这里，否则会把已加载内容隐藏。
  final Object? initialError;

  /// 分页加载错误。
  ///
  /// 只用于底部 retry，保留现有 items 和 selected category。
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

/// 首页分类与分页控制器。
///
/// Home 只负责 drama 列表，不创建播放器 media session。首页首屏预热由 HomePage
/// 监听成功加载后触发 PlayerStartupPreloadController，并且只做 HLS/source 预热；
/// 真正播放必须等用户进入 PlayerPage 后由 PlayerPlaybackController 接管。
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
      // 分类和第一页 feed 属于同一代请求。切分类/重试时旧请求返回必须丢弃，
      // 否则旧分类的分页 token 会覆盖新分类。
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

    // 分页不递增 generation，因为它属于当前分类的追加请求；但完成时仍检查分类 id，
    // 防止用户切分类后旧分页结果 append 到新列表。
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
