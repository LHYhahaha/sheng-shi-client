import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/my_list_repository_provider.dart';
import '../domain/my_list_item.dart';

final myListControllerProvider =
    NotifierProvider<MyListController, MyListState>(MyListController.new);

/// 片单页状态。
///
/// 收藏列表和播放列表共享页面骨架，但交互边界不同：收藏列表支持批量编辑/选择/删除，
/// 播放列表支持单条滑出删除。`openPlayItemId` 只服务播放列表滑动状态，进入编辑、
/// 切 tab、删除或加载失败时都要清掉，避免旧行的 slidable 状态残留到新列表。
class MyListState {
  const MyListState({
    required this.selectedTab,
    required this.isCollectionEditing,
    required this.items,
    required this.selectedIds,
    required this.isLoading,
    required this.openPlayItemId,
    this.error,
  });

  const MyListState.initial()
    : selectedTab = MyListTab.collection,
      isCollectionEditing = false,
      items = const [],
      selectedIds = const {},
      isLoading = true,
      openPlayItemId = null,
      error = null;

  final MyListTab selectedTab;
  final bool isCollectionEditing;
  final List<MyListItem> items;
  final Set<String> selectedIds;
  final bool isLoading;
  final Object? error;
  final String? openPlayItemId;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;

  int get selectedCount => selectedIds.length;

  bool get canEditCollection => selectedTab == MyListTab.collection;

  MyListState copyWith({
    MyListTab? selectedTab,
    bool? isCollectionEditing,
    List<MyListItem>? items,
    Set<String>? selectedIds,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    String? openPlayItemId,
    bool clearOpenPlayItemId = false,
  }) {
    return MyListState(
      selectedTab: selectedTab ?? this.selectedTab,
      isCollectionEditing: isCollectionEditing ?? this.isCollectionEditing,
      items: items ?? this.items,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
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

  @override
  MyListState build() => const MyListState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    // 重新加载会退出编辑并关闭已打开的播放列表滑动项。列表来源变了以后继续保留
    // selection/open item 会让删除操作命中不存在或错误的条目。
    state = state.copyWith(
      isLoading: true,
      isCollectionEditing: false,
      selectedIds: const {},
      clearError: true,
      clearOpenPlayItemId: true,
    );

    try {
      final items = await ref
          .read(myListRepositoryProvider)
          .fetchItems(tab: state.selectedTab);
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        items: List<MyListItem>.unmodifiable(items),
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }

      state = state.copyWith(
        items: const [],
        isLoading: false,
        error: error,
        clearOpenPlayItemId: true,
      );
    }
  }

  Future<void> retry() => load();

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
    if (!state.canEditCollection) {
      return;
    }

    // 只有收藏列表允许批量编辑。播放列表用单行滑动删除，两套交互不能同时存在，
    // 否则底部删除栏和 slidable 删除会对同一列表产生冲突。
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

  void toggleSelection(String id) {
    if (!state.isCollectionEditing) {
      return;
    }

    final selectedIds = {...state.selectedIds};
    if (!selectedIds.add(id)) {
      selectedIds.remove(id);
    }
    state = state.copyWith(selectedIds: Set<String>.unmodifiable(selectedIds));
  }

  void deleteSelected() {
    if (state.selectedIds.isEmpty) {
      return;
    }

    final selectedIds = state.selectedIds;
    // mock 阶段本地删除是乐观结果；真实接口接入后，这里应成为发起批量删除和
    // 失败回滚的唯一入口，避免 UI 层各自过滤列表。
    state = state.copyWith(
      items: List<MyListItem>.unmodifiable(
        state.items.where((item) => !selectedIds.contains(item.id)),
      ),
      selectedIds: const {},
      isCollectionEditing: false,
      clearOpenPlayItemId: true,
    );
  }

  void deleteItem(String id) {
    state = state.copyWith(
      items: List<MyListItem>.unmodifiable(
        state.items.where((item) => item.id != id),
      ),
      selectedIds: Set<String>.unmodifiable(
        state.selectedIds.where((selectedId) => selectedId != id),
      ),
      clearOpenPlayItemId: true,
    );
  }

  void openPlayItem(String id) {
    if (state.selectedTab != MyListTab.play || state.isCollectionEditing) {
      return;
    }

    // 只记录一个打开项，配合 SlidableAutoCloseBehavior 保证播放列表不会同时露出
    // 多个删除动作。编辑态下不允许打开，避免批量选择和单行删除混用。
    state = state.copyWith(openPlayItemId: id);
  }

  void closeOpenPlayItem(String id) {
    if (state.openPlayItemId != id) {
      return;
    }

    state = state.copyWith(clearOpenPlayItemId: true);
  }

  void closeAnyOpenPlayItem() {
    state = state.copyWith(clearOpenPlayItemId: true);
  }

  bool _isCurrent(int generation) => generation == _generation;
}
