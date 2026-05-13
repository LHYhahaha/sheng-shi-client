import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/my_list_repository_provider.dart';
import '../domain/my_list_item.dart';

final myListControllerProvider =
    NotifierProvider<MyListController, MyListState>(MyListController.new);

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

class MyListController extends Notifier<MyListState> {
  int _generation = 0;

  @override
  MyListState build() => const MyListState.initial();

  Future<void> load() async {
    final generation = ++_generation;
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
