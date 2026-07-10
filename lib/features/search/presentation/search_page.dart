import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/modal/app_modal_policy.dart';
import '../../../../core/modal/app_modal_provider.dart';
import '../../../../core/modal/app_modal_request.dart';
import '../../../../core/modal/app_modal_result.dart';
import '../../../../core/modal/app_modal_source.dart';
import '../../../../core/utils/compact_count_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../player/domain/player_feed.dart';
import '../application/search_history_controller.dart';
import '../application/search_rankings_controller.dart';
import '../application/search_recommendations_controller.dart';
import '../application/search_results_controller.dart';
import '../domain/search_rankings.dart';
import '../domain/search_results.dart';

enum _SearchViewMode { initial, suggestions, results }

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _rankingTypes = SearchRankingType.values;
  static const _rankingViewportFraction = 0.88;

  final _searchController = TextEditingController();
  final _rankingScrollController = ScrollController();
  Timer? _searchDebounce;
  double _rankingViewportWidth = 0;
  _SearchViewMode _viewMode = _SearchViewMode.initial;
  SearchSortType _selectedSort = SearchSortType.hottest;
  int _selectedRanking = 0;
  bool _showAllHistory = false;
  bool _isEditingHistory = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(searchRankingsControllerProvider.notifier).loadRankings(),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _rankingScrollController.dispose();
    super.dispose();
  }

  void _selectRanking(int index) {
    if (_selectedRanking == index) return;
    setState(() => _selectedRanking = index);
    _rankingScrollController.animateTo(
      _rankingOffsetFor(index),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  double _rankingOffsetFor(int index) {
    if (_rankingViewportWidth <= 0) return 0;
    final itemWidth = _rankingViewportWidth * _rankingViewportFraction;
    final maxOffset = _rankingTypes.length * itemWidth - _rankingViewportWidth;
    if (index <= 0) return 0;
    if (index >= _rankingTypes.length - 1) return maxOffset;
    return index * itemWidth - (_rankingViewportWidth - itemWidth) / 2;
  }

  void _updateSelectedRanking() {
    if (!_rankingScrollController.hasClients) return;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < _rankingTypes.length; index++) {
      final distance =
          (_rankingScrollController.offset - _rankingOffsetFor(index)).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    if (nearestIndex != _selectedRanking) {
      setState(() => _selectedRanking = nearestIndex);
    }
  }

  void _submitSearch(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _viewMode = _SearchViewMode.results;
      _selectedSort = SearchSortType.hottest;
    });
    unawaited(ref.read(searchHistoryControllerProvider.notifier).add(keyword));
    unawaited(
      ref
          .read(searchResultsControllerProvider.notifier)
          .search(keyword: keyword, sortType: _selectedSort),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty) {
      ref.read(searchSuggestionsControllerProvider.notifier).clear();
      setState(() => _viewMode = _SearchViewMode.initial);
      return;
    }
    setState(() => _viewMode = _SearchViewMode.suggestions);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchSuggestionsControllerProvider.notifier).search(keyword);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(searchSuggestionsControllerProvider.notifier).clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _viewMode = _SearchViewMode.initial;
      _selectedSort = SearchSortType.hottest;
    });
  }

  void _selectSort(SearchSortType sortType) {
    if (_selectedSort == sortType) return;
    setState(() => _selectedSort = sortType);
    unawaited(
      ref
          .read(searchResultsControllerProvider.notifier)
          .search(keyword: _searchController.text, sortType: sortType),
    );
  }

  Future<void> _confirmClearHistory() async {
    final result = await ref
        .read(appModalServiceProvider)
        .showConfirm(
          ConfirmModalRequest(
            requestId: ref.read(appModalControllerProvider).nextRequestId(),
            source: AppModalSource.search,
            priority: AppModalPriority.normal,
            dismissPolicy: AppModalDismissPolicy.standard,
            title: context.l10n.searchHistoryClearConfirm,
            message: '',
            confirmLabel: context.l10n.searchHistoryConfirm,
            cancelLabel: context.l10n.searchHistoryCancel,
          ),
        );
    if (!mounted || result != ConfirmResult.confirmed) {
      return;
    }
    await ref.read(searchHistoryControllerProvider.notifier).clear();
    if (!mounted) return;
    setState(() {
      _showAllHistory = false;
      _isEditingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchRankingsControllerProvider);
    final suggestions = ref.watch(searchSuggestionsControllerProvider);
    final results = ref.watch(searchResultsControllerProvider);
    final searchHistory = ref.watch(searchHistoryControllerProvider).items;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              _SearchBar(
                controller: _searchController,
                onBack: context.pop,
                onSubmitted: _submitSearch,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
              if (_viewMode == _SearchViewMode.initial &&
                  searchHistory.isNotEmpty)
                _SearchHistory(
                  items: searchHistory,
                  showAll: _showAllHistory,
                  isEditing: _isEditingHistory,
                  onToggle: () {
                    setState(() => _showAllHistory = !_showAllHistory);
                  },
                  onEdit: () {
                    setState(() => _isEditingHistory = true);
                  },
                  onCancelEdit: () {
                    setState(() => _isEditingHistory = false);
                  },
                  onClear: _confirmClearHistory,
                  onRemove: (keyword) {
                    unawaited(
                      ref
                          .read(searchHistoryControllerProvider.notifier)
                          .remove(keyword),
                    );
                    if (searchHistory.length == 1) {
                      setState(() {
                        _isEditingHistory = false;
                      });
                    }
                  },
                  onSelected: (keyword) {
                    _searchController
                      ..text = keyword
                      ..selection = TextSelection.collapsed(
                        offset: keyword.length,
                      );
                    _submitSearch(keyword);
                  },
                ),
              if (_viewMode == _SearchViewMode.initial) ...[
                _RankingTabs(
                  selectedIndex: _selectedRanking,
                  onSelected: _selectRanking,
                ),
                Expanded(
                  child: state.isInitialLoading
                      ? const Center(
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : state.hasPageError
                      ? _SearchErrorState(
                          onRetry: () => ref
                              .read(searchRankingsControllerProvider.notifier)
                              .retryAll(),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            _rankingViewportWidth = constraints.maxWidth;
                            final itemWidth =
                                constraints.maxWidth * _rankingViewportFraction;
                            return NotificationListener<ScrollEndNotification>(
                              onNotification: (notification) {
                                _updateSelectedRanking();
                                return false;
                              },
                              child: ListView.builder(
                                controller: _rankingScrollController,
                                scrollDirection: Axis.horizontal,
                                physics: _RankingSnapPhysics(
                                  viewportWidth: constraints.maxWidth,
                                  itemWidth: itemWidth,
                                  itemCount: _rankingTypes.length,
                                ),
                                itemCount: _rankingTypes.length,
                                itemBuilder: (context, index) {
                                  final type = _rankingTypes[index];
                                  return SizedBox(
                                    width: itemWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: _RankingPanel(
                                        type: type,
                                        state: state.rankingFor(type),
                                        onRetry: () => ref
                                            .read(
                                              searchRankingsControllerProvider
                                                  .notifier,
                                            )
                                            .retry(type),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ] else if (_viewMode == _SearchViewMode.suggestions)
                Expanded(
                  child: _SuggestionResults(
                    state: suggestions,
                    onRetry: () => ref
                        .read(searchSuggestionsControllerProvider.notifier)
                        .search(_searchController.text),
                    onLoadMore: () => ref
                        .read(searchSuggestionsControllerProvider.notifier)
                        .loadMore(),
                    onTap: (drama) {
                      _searchController
                        ..text = drama.title
                        ..selection = TextSelection.collapsed(
                          offset: drama.title.length,
                        );
                      _submitSearch(drama.title);
                    },
                  ),
                )
              else ...[
                _ResultSortTabs(
                  selected: _selectedSort,
                  onSelected: _selectSort,
                ),
                Expanded(
                  child: _SubmittedSearchResults(
                    state: results,
                    onRetry: () => ref
                        .read(searchResultsControllerProvider.notifier)
                        .search(
                          keyword: _searchController.text,
                          sortType: _selectedSort,
                        ),
                    onLoadMore: () => ref
                        .read(searchResultsControllerProvider.notifier)
                        .loadMore(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingSnapPhysics extends ScrollPhysics {
  const _RankingSnapPhysics({
    required this.viewportWidth,
    required this.itemWidth,
    required this.itemCount,
    super.parent,
  });

  final double viewportWidth;
  final double itemWidth;
  final int itemCount;

  @override
  _RankingSnapPhysics applyTo(ScrollPhysics? ancestor) {
    return _RankingSnapPhysics(
      viewportWidth: viewportWidth,
      itemWidth: itemWidth,
      itemCount: itemCount,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final targets = <double>[
      position.minScrollExtent,
      for (var index = 1; index < itemCount - 1; index++)
        index * itemWidth - (viewportWidth - itemWidth) / 2,
      position.maxScrollExtent,
    ];
    var target = targets.reduce(
      (current, candidate) =>
          (candidate - position.pixels).abs() <
              (current - position.pixels).abs()
          ? candidate
          : current,
    );

    if (velocity.abs() >= minFlingVelocity) {
      if (velocity > 0) {
        target = targets.firstWhere(
          (candidate) => candidate > position.pixels + 0.5,
          orElse: () => targets.last,
        );
      } else {
        target = targets.lastWhere(
          (candidate) => candidate < position.pixels - 0.5,
          orElse: () => targets.first,
        );
      }
    }

    if ((target - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onBack,
    required this.onSubmitted,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('search_back_button'),
            onTap: onBack,
            child: Container(
              width: 30,
              height: 30,
              margin: EdgeInsets.only(right: 3),
              alignment: Alignment.center,
              child: Icon(Icons.chevron_left, color: Colors.white, size: 28),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: controller,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: context.l10n.searchHint,
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 15, right: 4),
                    child: GestureDetector(
                      key: const ValueKey('search_submit_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSubmitted(controller.text),
                      child: Image.asset(
                        'assets/images/search/search_grey.png',
                        width: 14,
                        height: 14,
                      ),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        key: const ValueKey('search_clear_button'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onClear,
                        child: Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Color(0xFF353535),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      );
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.textPrimary.withValues(alpha: 0.14),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      width: 0.5,
                      color: AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      width: 0.5,
                      color: AppColors.textPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionResults extends StatelessWidget {
  const _SuggestionResults({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    required this.onTap,
  });

  final SearchSuggestionsState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<SearchResultDrama> onTap;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.error != null) {
      return Center(
        child: Text(
          '网络异常，请稍后重试',
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      );
    }
    final dramas = state.data?.dramas ?? const <SearchResultDrama>[];
    if (dramas.isEmpty) return const SizedBox.shrink();
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) onLoadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(6, 0, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: dramas.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index < dramas.length) {
            final drama = dramas[index];
            return _SearchDramaTile(drama: drama, onTap: () => onTap(drama));
          }
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (state.loadMoreError != null) {
            return _NetworkRetry(onRetry: onLoadMore, compact: true);
          }
          return const SizedBox(height: 12);
        },
      ),
    );
  }
}

class _ResultSortTabs extends StatelessWidget {
  const _ResultSortTabs({required this.selected, required this.onSelected});

  final SearchSortType selected;
  final ValueChanged<SearchSortType> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      SearchSortType.hottest: 'Trending',
      SearchSortType.newest: 'Latest',
      SearchSortType.unwatched: 'Unwatched',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 16, 20),
      child: Row(
        children: [
          for (final type in SearchSortType.values)
            GestureDetector(
              key: ValueKey('search_sort_${type.value}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(type),
              child: Padding(
                padding: const EdgeInsets.only(right: 24),
                child: Text(
                  labels[type]!,
                  style: TextStyle(
                    color: selected == type
                        ? const Color(0xFFFF007A)
                        : const Color(0xFF858585),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmittedSearchResults extends ConsumerWidget {
  const _SubmittedSearchResults({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
  });

  final SearchResultsState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (state.error != null) {
      return _NetworkRetry(onRetry: onRetry);
    }
    final dramas = state.data?.dramas ?? const <SearchResultDrama>[];
    if (dramas.isEmpty) {
      final recommendations = ref.watch(searchRecommendationsProvider);
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 25, bottom: 120),
              child: AppEmptyState(message: context.l10n.emptyNoDramas),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 16, 12),
              child: Text(
                'Recommend more',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14),
              ),
            ),
          ),
          recommendations.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => SliverToBoxAdapter(
              child: _NetworkRetry(
                onRetry: () => ref.invalidate(searchRecommendationsProvider),
              ),
            ),
            data: (items) => SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(left: 6, right: 16),
                child: _RecommendationTile(item: items[index]),
              ),
            ),
          ),
        ],
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) onLoadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(6, 0, 16, 24),
        itemCount: dramas.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index < dramas.length) {
            return _SearchDramaTile(
              drama: dramas[index],
              onTap: () => _openDrama(context, dramas[index].id),
            );
          }
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (state.loadMoreError != null) {
            return _NetworkRetry(onRetry: onLoadMore, compact: true);
          }
          if (!state.hasMore) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '没有更多了',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }
          return const SizedBox(height: 24);
        },
      ),
    );
  }
}

class _SearchDramaTile extends StatelessWidget {
  const _SearchDramaTile({required this.drama, required this.onTap});

  final SearchResultDrama drama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DramaTileLayout(
      coverUrl: drama.coverUrl,
      title: drama.title,
      tags: drama.tags,
      summary: drama.summary,
      onTap: onTap,
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.item});

  final PlayerFeedItem item;

  @override
  Widget build(BuildContext context) {
    final content = item.content;
    return _DramaTileLayout(
      coverUrl: content.coverUrl ?? '',
      title: content.title,
      tags: content.tags,
      summary: content.synopsis,
      onTap: () => _openDrama(context, content.id),
    );
  }
}

class _DramaTileLayout extends StatelessWidget {
  const _DramaTileLayout({
    required this.coverUrl,
    required this.title,
    required this.tags,
    required this.summary,
    required this.onTap,
  });

  final String coverUrl;
  final String title;
  final List<String> tags;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AppCachedNetworkImage(
                imageUrl: coverUrl,
                width: 82,
                height: 111,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(height: 20, child: _SearchTagsRow(tags: tags)),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary.withValues(alpha: 0.5),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchTagsRow extends StatelessWidget {
  const _SearchTagsRow({required this.tags});

  static const _gap = 6.0;
  static const _horizontalPadding = 16.0;
  static const _textStyle = TextStyle(color: Color(0xFF999999), fontSize: 12);

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveTextStyle = DefaultTextStyle.of(
          context,
        ).style.merge(_textStyle);
        final visibleTags = _visibleTagsForWidth(
          context,
          constraints.maxWidth,
          effectiveTextStyle,
        );
        return Row(
          children: [
            for (final tag in visibleTags.indexed) ...[
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  tag.$2,
                  maxLines: 1,
                  softWrap: false,
                  style: effectiveTextStyle,
                ),
              ),
              if (tag.$1 != visibleTags.length - 1) const SizedBox(width: _gap),
            ],
          ],
        );
      },
    );
  }

  List<String> _visibleTagsForWidth(
    BuildContext context,
    double maxWidth,
    TextStyle effectiveTextStyle,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) return const [];
    final visibleTags = <String>[];
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    var usedWidth = 0.0;

    for (final tag in tags) {
      final painter = TextPainter(
        text: TextSpan(text: tag, style: effectiveTextStyle),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      // Leave one physical-layout pixel for font fallback and fractional
      // glyph rounding differences between TextPainter and RenderParagraph.
      final tagWidth = painter.width.ceilToDouble() + _horizontalPadding + 1;
      final nextWidth = usedWidth + (visibleTags.isEmpty ? 0 : _gap) + tagWidth;
      if (nextWidth > maxWidth) break;
      visibleTags.add(tag);
      usedWidth = nextWidth;
    }
    return visibleTags;
  }
}

class _NetworkRetry extends StatelessWidget {
  const _NetworkRetry({required this.onRetry, this.compact = false});

  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '网络异常，请重试',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

void _openDrama(BuildContext context, String dramaId) {
  context.push(
    RoutePaths.playerLocation(
      dramaId: dramaId,
      episodeId: '1',
      trigger: 'search_result_tap',
      userActionAtMs: DateTime.now().millisecondsSinceEpoch,
    ),
  );
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.items,
    required this.showAll,
    required this.isEditing,
    required this.onToggle,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onClear,
    required this.onRemove,
    required this.onSelected,
  });

  final List<String> items;
  final bool showAll;
  final bool isEditing;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onClear;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 34;
    final collapsedCount = _collapsedItemCount(context, availableWidth);
    final hasOverflow = collapsedCount < items.length;
    final visibleItems = isEditing || showAll
        ? items
        : items.take(collapsedCount).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.searchHistory,
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                ),
              ),
              if (isEditing) ...[
                GestureDetector(
                  onTap: onCancelEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      context.l10n.searchHistoryCancel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.textPrimary.withValues(alpha: 0.2),
                ),
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      context.l10n.searchHistoryClearAll,
                      style: TextStyle(color: Color(0XFFFF4063), fontSize: 12),
                    ),
                  ),
                ),
              ] else
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      'assets/images/search/delete.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in visibleItems)
                _HistoryChip(
                  label: item,
                  isEditing: isEditing,
                  onTap: () => onSelected(item),
                  onRemove: () => onRemove(item),
                ),
              if (!isEditing && hasOverflow)
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 32,
                    height: 27,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedRotation(
                      turns: showAll ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  int _collapsedItemCount(BuildContext context, double availableWidth) {
    final widths = [for (final item in items) _historyChipWidth(context, item)];
    if (_fitsWithinRows(widths, availableWidth, 2)) {
      return items.length;
    }

    const expandButtonWidth = 32.0;
    var visibleCount = 0;
    for (var count = 1; count <= widths.length; count++) {
      final candidateWidths = [...widths.take(count), expandButtonWidth];
      if (!_fitsWithinRows(candidateWidths, availableWidth, 2)) {
        break;
      }
      visibleCount = count;
    }
    return visibleCount;
  }

  double _historyChipWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 12)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 125);
    return (painter.width + 20).clamp(20, 145);
  }

  bool _fitsWithinRows(
    Iterable<double> widths,
    double availableWidth,
    int maxRows,
  ) {
    const spacing = 8.0;
    var rows = 1;
    var usedWidth = 0.0;
    for (final width in widths) {
      final nextWidth = usedWidth == 0 ? width : usedWidth + spacing + width;
      if (nextWidth <= availableWidth) {
        usedWidth = nextWidth;
        continue;
      }
      rows += 1;
      if (rows > maxRows) {
        return false;
      }
      usedWidth = width;
    }
    return true;
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    required this.label,
    required this.isEditing,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEditing ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 145),
        padding: EdgeInsets.fromLTRB(10, 6, isEditing ? 5 : 10, 6),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12),
              ),
            ),
            if (isEditing) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Color(0xFF353535),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankingTabs extends StatelessWidget {
  const _RankingTabs({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.searchHot,
      context.l10n.searchTrending,
      context.l10n.searchNewReleases,
    ];
    final colors = const [
      Color(0xFFFF007A),
      Color(0xFFFBB829),
      Color(0xFFC05AFF),
    ];

    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Flexible(
            child: InkWell(
              onTap: () => onSelected(index),
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 6 : 10,
                  right: 7,
                  bottom: 12,
                ),
                child: Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selectedIndex == index
                        ? colors[index]
                        : const Color(0xFF858585),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({
    required this.type,
    required this.state,
    required this.onRetry,
  });

  final SearchRankingType type;
  final SearchRankingState state;
  final VoidCallback onRetry;

  String get _backgroundAsset => switch (type) {
    SearchRankingType.hotSearches => 'assets/images/search/red_bac.png',
    SearchRankingType.hotPlays => 'assets/images/search/yellow_bac.png',
    SearchRankingType.newOnline => 'assets/images/search/purple_bac.png',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 4, left: 10, right: 10),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_backgroundAsset),
          fit: BoxFit.fill,
        ),
      ),
      child: state.isLoading && state.data == null
          ? const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : state.error != null
          ? _SearchErrorState(onRetry: onRetry)
          : state.isEmpty
          ? Center(child: AppEmptyState(message: context.l10n.emptyNoDramas))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
              itemCount: state.data?.dramas.length ?? 0,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final drama = state.data!.dramas[index];
                return _RankingDramaTile(
                  drama: drama,
                  ranking: index + 1,
                  onTap: () {
                    final tappedAt = DateTime.now();
                    context.push(
                      RoutePaths.playerLocation(
                        dramaId: drama.id,
                        episodeId: '1',
                        trigger: 'search_ranking_tap',
                        userActionAtMs: tappedAt.millisecondsSinceEpoch,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _RankingDramaTile extends StatelessWidget {
  const _RankingDramaTile({
    required this.drama,
    required this.ranking,
    required this.onTap,
  });

  final SearchRankDrama drama;
  final int ranking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 73,
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AppCachedNetworkImage(
                    imageUrl: drama.coverUrl,
                    width: 60,
                    height: 82,
                    fit: BoxFit.cover,
                  ),
                ),
                if (ranking <= 4) _RankBadge(ranking: ranking),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Flexible(
                        child: SizedBox(
                          height: 20,
                          child: _SearchTagsRow(tags: drama.tags),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '🔥 ${formatCompactCount(drama.searchCount, lowercaseSuffix: true)}',
                        style: const TextStyle(
                          color: Color(0xFFECECEC),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.ranking});

  final int ranking;

  @override
  Widget build(BuildContext context) {
    final color = switch (ranking) {
      1 => const Color(0xFFFB4729),
      2 => const Color(0xFFFBB829),
      3 => const Color(0xFFFF007A),
      _ => const Color(0xFF424242),
    };
    return Container(
      width: 24,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        '$ranking',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchErrorState extends StatelessWidget {
  const _SearchErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.feedLoadFailed,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}
