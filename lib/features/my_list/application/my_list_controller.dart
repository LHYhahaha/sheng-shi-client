import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_cleanup_types.dart';
import '../data/my_list_repository_provider.dart';
import '../domain/my_list_item.dart';

/// My list feature 的唯一状态入口。
///
/// 收藏批量编辑和播放列表左滑删除都依赖同一份列表状态。UI 不直接过滤 items，
/// 是为了后续接真实收藏/播放历史接口时能统一做乐观更新、失败回滚和 after-delete
/// empty 状态。
final myListControllerProvider =
    NotifierProvider<MyListController, MyListState>(MyListController.new);

/// 片单页状态。
///
/// 收藏列表和播放列表共享页面骨架和编辑交互。两个 tab 都支持批量编辑/选择/删除，
/// 也都支持单行滑动删除。`openPlayItemId` 记录当前打开的滑动删除项，进入编辑、
/// 切 tab、删除或加载失败时都要清掉，避免旧行的 slidable 状态残留到新列表。
class MyListState {
  const MyListState({
    required this.selectedTab,
    required this.isCollectionEditing,
    required this.items,
    required this.selectedIds,
    required this.isLoading,
    required this.isLoadingMore,
    required this.openPlayItemId,
    this.nextPageToken,
    this.error,
    this.loadMoreError,
  });

  const MyListState.initial()
    : selectedTab = MyListTab.collection,
      isCollectionEditing = false,
      items = const [],
      selectedIds = const {},
      isLoading = true,
      isLoadingMore = false,
      openPlayItemId = null,
      nextPageToken = null,
      error = null,
      loadMoreError = null;

  /// 当前选中的片单 tab。
  ///
  /// collection 和 play 的交互不同：collection 才能批量编辑，play 才能滑动删除。
  final MyListTab selectedTab;

  /// 收藏列表是否处于批量编辑模式。
  ///
  /// 两个 tab 都支持编辑。进入编辑会隐藏 shell bottom navigation，并关闭
  /// 任何打开的 slidable 状态。
  final bool isCollectionEditing;

  /// 当前 tab 下展示的条目。
  ///
  /// mock 删除会本地过滤这个列表；真实接口接入后，这里仍应只保存 controller 统一
  /// 处理后的结果，UI 不直接改集合。
  final List<MyListItem> items;

  /// 批量编辑时选中的 item id 集合。
  ///
  /// 两个 tab 都支持编辑。切 tab、reload、删除后必须清空，避免选择态命中
  /// 已不存在的条目。
  final Set<int> selectedIds;

  /// 当前列表是否正在加载。
  ///
  /// loading 会退出编辑并清空 selection/open item，确保新数据到来前没有旧交互状态。
  final bool isLoading;

  final bool isLoadingMore;

  /// 当前 tab 加载失败的错误。
  ///
  /// 只用于整页 retry，不表示删除失败。后续删除接口失败应有独立动作错误或回滚机制。
  final Object? error;

  final Object? loadMoreError;

  final String? nextPageToken;

  /// 播放列表当前打开滑动删除动作的 item id。
  ///
  /// 只允许一个打开项。两个 tab 都支持滑动删除，切 tab/删除/reload/进入编辑都要清空。
  final int? openPlayItemId;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  bool get canLoadMore =>
      !isLoading &&
      !isLoadingMore &&
      error == null &&
      loadMoreError == null &&
      nextPageToken != null &&
      !isCollectionEditing;

  int get selectedCount => selectedIds.length;

  bool get areAllItemsSelected =>
      items.isNotEmpty &&
      items.every((item) => selectedIds.contains(item.dramaId));

  bool get canEditCollection => true;

  MyListState copyWith({
    MyListTab? selectedTab,
    bool? isCollectionEditing,
    List<MyListItem>? items,
    Set<int>? selectedIds,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
    String? nextPageToken,
    bool clearNextPageToken = false,
    int? openPlayItemId,
    bool clearOpenPlayItemId = false,
  }) {
    return MyListState(
      selectedTab: selectedTab ?? this.selectedTab,
      isCollectionEditing: isCollectionEditing ?? this.isCollectionEditing,
      items: items ?? this.items,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : error ?? this.error,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
      nextPageToken: clearNextPageToken
          ? null
          : nextPageToken ?? this.nextPageToken,
      openPlayItemId: clearOpenPlayItemId
          ? null
          : openPlayItemId ?? this.openPlayItemId,
    );
  }
}

/// My list 状态控制器。
///
/// 控制器集中处理 tab、loading/error/empty、编辑选择和删除。UI 不直接改列表集合，
/// 是为了后续接真实收藏/播放历史接口时能在这里统一处理乐观更新、失败回滚和重试。
class MyListController extends Notifier<MyListState> {
  int _generation = 0;
  bool _isLoadMoreRequestInFlight = false;

  @override
  MyListState build() => const MyListState.initial();

  /// 清空登录态片单缓存，下次进入 tab 会重新 load。
  void resetForSessionCleanup(SessionCleanupReason reason) {
    ++_generation;
    _isLoadMoreRequestInFlight = false;
    state = const MyListState.initial();
  }

  Future<void> load() async {
    final generation = ++_generation;
    _isLoadMoreRequestInFlight = false;
    // 重新加载会退出编辑并关闭已打开的播放列表滑动项。列表来源变了以后继续保留
    // selection/open item 会让删除操作命中不存在或错误的条目。
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      isCollectionEditing: false,
      selectedIds: const {},
      clearError: true,
      clearLoadMoreError: true,
      clearNextPageToken: true,
      clearOpenPlayItemId: true,
    );

    try {
      final page = await ref
          .read(myListRepositoryProvider)
          .fetchPage(tab: state.selectedTab);
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        items: List<MyListItem>.unmodifiable(page.items),
        nextPageToken: page.nextPageToken,
        clearNextPageToken: page.nextPageToken == null,
        isLoading: false,
        clearError: true,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        items: const [],
        isLoading: false,
        isLoadingMore: false,
        error: error,
        clearLoadMoreError: true,
        clearNextPageToken: true,
        clearOpenPlayItemId: true,
      );
    }
  }

  Future<void> retry() => load();

  Future<void> refreshCurrentTabInPlace() async {
    if (state.isLoading || state.isLoadingMore || state.error != null) {
      return;
    }

    final generation = ++_generation;
    final tab = state.selectedTab;
    final targetItemCount = state.items.length;
    _isLoadMoreRequestInFlight = true;

    try {
      final repository = ref.read(myListRepositoryProvider);
      var page = await repository.fetchPage(tab: tab);
      final refreshedItems = <MyListItem>[...page.items];
      var nextPageToken = page.nextPageToken;

      while (nextPageToken != null && refreshedItems.length < targetItemCount) {
        page = await repository.fetchPage(tab: tab, pageToken: nextPageToken);
        refreshedItems.addAll(page.items);
        nextPageToken = page.nextPageToken;
      }

      if (!_isCurrent(generation) || state.selectedTab != tab) {
        return;
      }

      state = state.copyWith(
        items: List<MyListItem>.unmodifiable(refreshedItems),
        nextPageToken: nextPageToken,
        clearNextPageToken: nextPageToken == null,
        clearLoadMoreError: true,
        clearOpenPlayItemId: true,
      );
    } catch (_) {
      if (!_isCurrent(generation) || state.selectedTab != tab) {
        return;
      }
      state = state.copyWith(clearOpenPlayItemId: true);
    } finally {
      _isLoadMoreRequestInFlight = false;
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    if (_isLoadMoreRequestInFlight) {
      return;
    }
    if (retry) {
      if (state.isLoading ||
          state.isLoadingMore ||
          state.error != null ||
          state.nextPageToken == null ||
          state.isCollectionEditing) {
        return;
      }
    } else if (!state.canLoadMore) {
      return;
    }

    final generation = _generation;
    final pageToken = state.nextPageToken;
    final tab = state.selectedTab;
    if (pageToken == null) {
      return;
    }

    _isLoadMoreRequestInFlight = true;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    try {
      final page = await ref
          .read(myListRepositoryProvider)
          .fetchPage(tab: tab, pageToken: pageToken);
      if (!_isCurrent(generation) || state.selectedTab != tab) {
        return;
      }

      state = state.copyWith(
        items: List<MyListItem>.unmodifiable([...state.items, ...page.items]),
        nextPageToken: page.nextPageToken,
        clearNextPageToken: page.nextPageToken == null,
        isLoadingMore: false,
        clearLoadMoreError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation) || state.selectedTab != tab) {
        return;
      }

      state = state.copyWith(isLoadingMore: false, loadMoreError: error);
    } finally {
      _isLoadMoreRequestInFlight = false;
    }
  }

  Future<void> selectTab(MyListTab tab) async {
    if (state.selectedTab == tab) {
      return;
    }

    // tab 切换是数据域切换，不沿用收藏列表的选择态，也不沿用播放列表的 slidable。
    state = state.copyWith(
      selectedTab: tab,
      isCollectionEditing: false,
      selectedIds: const {},
      clearOpenPlayItemId: true,
    );
    await load();
  }

  void enterCollectionEdit() {
    // 两个 tab 都支持批量编辑。进入编辑模式时关闭任何打开的 slidable，
    // 避免编辑和滑动删除混用。
    state = state.copyWith(
      isCollectionEditing: true,
      selectedIds: const {},
      clearOpenPlayItemId: true,
    );
  }

  void cancelCollectionEdit() {
    state = state.copyWith(
      isCollectionEditing: false,
      selectedIds: const {},
      clearOpenPlayItemId: true,
    );
  }

  void toggleSelection(int dramaId) {
    if (!state.isCollectionEditing) {
      return;
    }

    final selectedIds = {...state.selectedIds};
    if (!selectedIds.add(dramaId)) {
      selectedIds.remove(dramaId);
    }
    state = state.copyWith(selectedIds: Set<int>.unmodifiable(selectedIds));
  }

  void toggleSelectAll() {
    if (!state.isCollectionEditing) {
      return;
    }

    if (state.areAllItemsSelected) {
      state = state.copyWith(selectedIds: const {});
      return;
    }

    state = state.copyWith(
      selectedIds: Set<int>.unmodifiable(
        state.items.map((item) => item.dramaId),
      ),
    );
  }

  Future<void> deleteSelected() async {
    if (state.selectedIds.isEmpty) {
      return;
    }

    final selectedDramaIds = state.selectedIds;
    final tab = state.selectedTab;

    // 乐观更新：先本地删除
    state = state.copyWith(
      items: List<MyListItem>.unmodifiable(
        state.items.where((item) => !selectedDramaIds.contains(item.dramaId)),
      ),
      selectedIds: const {},
      isCollectionEditing: false,
      clearOpenPlayItemId: true,
    );

    // 调用远程接口
    try {
      final repository = ref.read(myListRepositoryProvider);
      final isCollection = tab == MyListTab.collection;
      
      if (isCollection) {
        // 收藏列表：使用 dramaId 删除
        await repository.deleteFavorites(dramaIds: selectedDramaIds.toList());
      } else {
        // 播放历史：使用 dramaId 删除
        await repository.deletePlayHistories(
          historyIds: selectedDramaIds.toList(),
        );
      }
    } catch (error) {
      // 删除失败时重新加载列表
      await load();
    }
  }

  Future<void> deleteItem(int dramaId) async {
    final tab = state.selectedTab;

    state = state.copyWith(
      items: List<MyListItem>.unmodifiable(
        state.items.where((item) => item.dramaId != dramaId),
      ),
      selectedIds: Set<int>.unmodifiable(
        state.selectedIds.where((selectedId) => selectedId != dramaId),
      ),
      clearOpenPlayItemId: true,
    );

    // 调用远程接口
    try {
      final repository = ref.read(myListRepositoryProvider);
      final isCollection = tab == MyListTab.collection;

      if (isCollection) {
        // 收藏列表：使用 dramaId 删除
        await repository.deleteFavorite(dramaId: dramaId);
      } else {
        // 播放历史：使用 dramaId 删除
        await repository.deletePlayHistory(historyId: dramaId);
      }
    } catch (error) {
      // 删除失败时重新加载列表
      await load();
    }
  }

  void openPlayItem(int dramaId) {
    if (state.isCollectionEditing) {
      return;
    }

    // 只记录一个打开项，配合 SlidableAutoCloseBehavior 保证两个 tab 都不会同时露出
    // 多个删除动作。编辑态下不允许打开，避免批量选择和单行删除混用。
    state = state.copyWith(openPlayItemId: dramaId);
  }

  void closeOpenPlayItem(int dramaId) {
    if (state.openPlayItemId != dramaId) {
      return;
    }

    state = state.copyWith(clearOpenPlayItemId: true);
  }

  void closeAnyOpenPlayItem() {
    state = state.copyWith(clearOpenPlayItemId: true);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
