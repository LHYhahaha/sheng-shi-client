import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../features/drama/data/drama_repository_provider.dart';
import '../../../../features/drama/domain/drama.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();
  final List<DramaCategory> _categories = [];
  final List<Drama> _items = [];

  int _selectedTab = 0;
  int _loadGeneration = 0;
  String? _nextPageToken;
  Object? _initialError;
  Object? _loadMoreError;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitialFeed());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_nextPageToken == null ||
        _isLoadingMore ||
        !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 500) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadInitialFeed({String? preferredCategoryId}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isInitialLoading = true;
      _isLoadingMore = false;
      _initialError = null;
      _loadMoreError = null;
      _nextPageToken = null;
      _items.clear();
    });

    try {
      final repository = ref.read(dramaRepositoryProvider);
      final categories = await repository.listHomeCategories();

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      if (categories.isEmpty) {
        setState(() {
          _categories.clear();
          _selectedTab = 0;
          _isInitialLoading = false;
        });
        return;
      }

      final selectedIndex = _resolveSelectedIndex(
        categories,
        preferredCategoryId,
      );
      final selectedCategory = categories[selectedIndex];
      final page = await repository.listHomeFeed(
        categoryId: selectedCategory.id,
      );

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _categories
          ..clear()
          ..addAll(categories);
        _selectedTab = selectedIndex;
        _items.addAll(page.items);
        _nextPageToken = page.nextPageToken;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _initialError = error;
        _isInitialLoading = false;
      });
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

  Future<void> _loadMore() async {
    final pageToken = _nextPageToken;
    if (pageToken == null || _categories.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final repository = ref.read(dramaRepositoryProvider);
      final page = await repository.listHomeFeed(
        categoryId: _categories[_selectedTab].id,
        pageToken: pageToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items.addAll(page.items);
        _nextPageToken = page.nextPageToken;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadMoreError = error;
        _isLoadingMore = false;
      });
    }
  }

  void _selectTab(int index) {
    if (_selectedTab == index || index >= _categories.length) {
      return;
    }

    final categoryId = _categories[index].id;
    setState(() {
      _selectedTab = index;
      _items.clear();
      _nextPageToken = null;
      _isInitialLoading = true;
      _isLoadingMore = false;
      _initialError = null;
      _loadMoreError = null;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }

    unawaited(_loadInitialFeed(preferredCategoryId: categoryId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _HomeTitleBar(
                  onMembershipTap: () => context.go(RoutePaths.membership),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeTabsHeaderDelegate(
                selectedTab: _selectedTab,
                tabs: List<DramaCategory>.unmodifiable(_categories),
                onTabChanged: _selectTab,
              ),
            ),
            if (_isInitialLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_initialError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeErrorState(onRetry: _loadInitialFeed),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    context.l10n.feedEmpty,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(13, 2, 12, 24),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.crossAxisExtent <= 0) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }

                    const crossAxisCount = 2;
                    const crossAxisSpacing = 8.0;
                    final tileWidth =
                        (constraints.crossAxisExtent -
                            crossAxisSpacing * (crossAxisCount - 1)) /
                        crossAxisCount;
                    final coverCacheWidth = math.max(
                      1,
                      (tileWidth * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    );

                    return SliverMasonryGrid.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: crossAxisSpacing,
                      childCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];

                        return _HomeDramaCard(
                          data: item,
                          coverCacheWidth: coverCacheWidth,
                          onTap: () {
                            context.go(
                              RoutePaths.playerLocation(
                                dramaId: item.id,
                                episodeId: 'episode-1',
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: _HomeFeedFooter(
                isLoading: _isLoadingMore,
                hasMore: _nextPageToken != null,
                error: _loadMoreError,
                onRetry: _loadMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTitleBar extends StatelessWidget {
  const _HomeTitleBar({required this.onMembershipTap});

  final VoidCallback onMembershipTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'KillgBox',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
          ),
        ),
        GestureDetector(
          onTap: onMembershipTap,
          child: const Padding(
            padding: EdgeInsets.only(right: 1),
            child: _VipCrown(),
          ),
        ),
      ],
    );
  }
}

class _VipCrown extends StatelessWidget {
  const _VipCrown();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mock/vip_crown_figma.png',
      width: 36,
      height: 34,
      cacheWidth: (36 * MediaQuery.devicePixelRatioOf(context)).round(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );
  }
}

class _HomeTabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeTabsHeaderDelegate({
    required this.tabs,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final List<DramaCategory> tabs;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.black,
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.72),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 13, 0, 0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tabs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 31),
            itemBuilder: (context, index) {
              return _HomeCategoryTab(
                label: tabs[index].title,
                selected: index == selectedTab,
                onTap: () => onTabChanged(index),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeTabsHeaderDelegate oldDelegate) {
    return oldDelegate.selectedTab != selectedTab || oldDelegate.tabs != tabs;
  }
}

class _HomeCategoryTab extends StatelessWidget {
  const _HomeCategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 15,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }
}

class _HomeDramaCard extends StatelessWidget {
  const _HomeDramaCard({
    required this.data,
    required this.coverCacheWidth,
    required this.onTap,
  });

  final Drama data;
  final int coverCacheWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A2230),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: data.coverAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    data.coverAssetPath,
                    cacheWidth: coverCacheWidth,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.low,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x66000000),
                        ],
                      ),
                    ),
                  ),
                  if (data.isExclusive)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: _ExclusiveBadge(),
                    ),
                  Positioned(
                    right: 9,
                    bottom: 10,
                    child: _ViewCount(label: data.viewCountLabel),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE0E0E0),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  if (data.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: [
                          for (final tag in data.tags.indexed) ...[
                            _HomeTag(label: tag.$2),
                            if (tag.$1 != data.tags.length - 1)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExclusiveBadge extends StatelessWidget {
  const _ExclusiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFF2267),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Text(
        context.l10n.exclusive,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          fontSize: 11,
          height: 14 / 11,
        ),
      ),
    );
  }
}

class _ViewCount extends StatelessWidget {
  const _ViewCount({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_arrow, color: AppColors.textPrimary, size: 14),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textPrimary,
            fontSize: 11,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _HomeTag extends StatelessWidget {
  const _HomeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x3DD9D9D9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFFC5BEC9),
          fontSize: 9,
          height: 1.3,
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.l10n.feedLoadFailed,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ],
    );
  }
}

class _HomeFeedFooter extends StatelessWidget {
  const _HomeFeedFooter({
    required this.isLoading,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final bool hasMore;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Center(
          child: isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : error != null
              ? TextButton(onPressed: onRetry, child: Text(context.l10n.retry))
              : Text(
                  hasMore ? '' : context.l10n.feedEmpty,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
        ),
      ),
    );
  }
}
