import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_swiper_plus/flutter_swiper_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/network/api_client_provider.dart';
import '../../../../core/notification/startup_notification_permission_reporter.dart';
import '../../../../features/drama/domain/drama.dart';
import '../../../../features/entitlement/application/entitlement_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/media/media_resource.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../application/home_data_controller.dart';
import '../../application/home_remote_data_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();
  final Map<int, double> _tabScrollOffsets = <int, double>{};
  int _remoteDataSelectedIndex = 0; // 远程数据的选中分类索引
  int _lastScrollToTopRequest = 0; // 跟踪上次的滚动请求计数
  ProviderSubscription<int>? _scrollToTopListener; // 监听滚动请求的订阅
  ProviderSubscription<bool>? _accessTokenListener;
  bool _notificationPermissionCheckScheduled = false;
  bool _notificationPermissionChecked = false;

  List image = [
    "assets/images/home/picture1.jpg",
    "assets/images/home/picture2.jpg",
    "assets/images/home/picture3.jpg",
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // 监听滚动到顶部的请求
    _scrollToTopListener = ref.listenManual(homeScrollToTopRequestProvider, (
      previous,
      next,
    ) {
      if (next > _lastScrollToTopRequest) {
        _lastScrollToTopRequest = next;
        _scrollToTop();
      }
    });

    _accessTokenListener = ref.listenManual(
      authTokenStoreProvider.select((state) => state.hasAccessToken),
      (_, hasAccessToken) {
        if (hasAccessToken) {
          _checkNotificationPermissionAfterFirstFrame();
        }
      },
      fireImmediately: true,
    );

    // 首页 remote 数据会在 HomeDataController 中监听 AuthState 自动加载
    // 不需要在这里手动加载 mock 数据，HomeFeedController 会根据 remote 数据的存在情况自动决定
  }

  @override
  void dispose() {
    // 取消滚动请求的监听
    _scrollToTopListener?.close();
    _accessTokenListener?.close();

    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _checkNotificationPermissionAfterFirstFrame() {
    if (_notificationPermissionChecked ||
        _notificationPermissionCheckScheduled) {
      return;
    }

    _notificationPermissionCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationPermissionCheckScheduled = false;
      if (!mounted || _notificationPermissionChecked) {
        return;
      }

      final accessToken = ref.read(apiRequestContextProvider).accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        return;
      }

      _notificationPermissionChecked = true;
      unawaited(
        ref
            .read(startupNotificationPermissionReporterProvider)
            .checkAndReportOnHomeArrival(),
      );
    });
  }

  void _onScroll() {
    final remoteData = ref.read(homeRemoteDataProvider);

    // Remote home data keeps pagination per tab.
    if (remoteData != null) {
      if (!_scrollController.hasClients) {
        return;
      }

      final tab = remoteData.getTabForCategoryIndex(_remoteDataSelectedIndex);
      final homeDataState = ref.read(homeDataControllerProvider);
      if (tab == null || !tab.hasMoreDramas || homeDataState.isLoadingMore) {
        return;
      }

      final position = _scrollController.position;
      if (position.extentAfter < 500) {
        ref.read(homeDataControllerProvider.notifier).loadMoreTab(tab.id);
      }
      return;
    }
  }

  void _saveCurrentTabScrollOffset(HomeRemoteData remoteData) {
    if (!_scrollController.hasClients) {
      return;
    }

    final tab = remoteData.getTabForCategoryIndex(_remoteDataSelectedIndex);
    if (tab == null) {
      return;
    }

    _tabScrollOffsets[tab.id] = _scrollController.offset;
  }

  void _restoreScrollOffsetForTab(int tabId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      final savedOffset = _tabScrollOffsets[tabId] ?? 0.0;
      final targetOffset = savedOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _scrollController.jumpTo(targetOffset);
    });
  }

  void _selectTab(int index) {
    final remoteData = ref.read(homeRemoteDataProvider);

    // 如果使用远程数据，更新选中索引并恢复该 tab 的滚动位置
    if (remoteData != null) {
      if (index < 0 || index >= remoteData.categories.length) {
        return;
      }

      if (index == _remoteDataSelectedIndex) {
        return;
      }

      final nextTab = remoteData.getTabForCategoryIndex(index);
      if (nextTab == null) {
        return;
      }

      _saveCurrentTabScrollOffset(remoteData);
      setState(() {
        _remoteDataSelectedIndex = index;
      });

      _restoreScrollOffsetForTab(nextTab.id);
      return;
    }

    // 使用 mock 数据的原有逻辑
  }

  /// 滚动到页面顶部
  void _scrollToTop() {
    final remoteData = ref.read(homeRemoteDataProvider);
    if (remoteData != null) {
      final tab = remoteData.getTabForCategoryIndex(_remoteDataSelectedIndex);
      if (tab != null) {
        _tabScrollOffsets[tab.id] = 0;
      }
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听远程数据
    final remoteData = ref.watch(homeRemoteDataProvider);
    final homeDataState = ref.watch(homeDataControllerProvider);

    // 监听 mock 数据

    // 决定使用哪个数据源：优先使用远程数据，降级到 mock 数据
    final categories = remoteData?.categories ?? const <DramaCategory>[];
    final selectedIndex = categories.isNotEmpty
        ? math.min(_remoteDataSelectedIndex, categories.length - 1)
        : 0;
    if (selectedIndex != _remoteDataSelectedIndex) {
      _remoteDataSelectedIndex = selectedIndex;
    }

    // 获取当前选中分类的剧卡列表
    final items =
        remoteData?.getDramasForCategoryIndex(selectedIndex) ?? const <Drama>[];
    final selectedRemoteTab = remoteData?.getTabForCategoryIndex(selectedIndex);

    // 判断加载状态
    final isLoading =
        homeDataState.isLoading ||
        (remoteData == null && homeDataState.error == null);
    final error = homeDataState.error;
    final isEmpty = items.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            final tab = selectedRemoteTab;
            if (tab == null) {
              await ref.read(homeDataControllerProvider.notifier).retry();
            } else {
              final selectedTabId = tab.id;
              await ref
                  .read(homeDataControllerProvider.notifier)
                  .refreshHomeData();
              if (!mounted) {
                return;
              }

              final refreshedRemoteData = ref.read(homeRemoteDataProvider);
              final nextIndex =
                  refreshedRemoteData?.tabs.indexWhere(
                    (tab) => tab.id == selectedTabId,
                  ) ??
                  -1;
              if (nextIndex != -1 && nextIndex != _remoteDataSelectedIndex) {
                setState(() {
                  _remoteDataSelectedIndex = nextIndex;
                });
              }
            }
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HomeFixedHeaderDelegate(
                  selectedTab: selectedIndex,
                  tabs: categories,
                  onTabChanged: (index) {
                    // 远程数据：直接更新选中索引
                    _selectTab(index);
                    // mock 数据：使用原有逻辑
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.only(
                    bottom: 10,
                    left: 14,
                    right: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Swiper(
                      itemBuilder: (BuildContext context, int index) {
                        return Image.asset(image[index], fit: BoxFit.fill);
                      },
                      autoplay: true,
                      itemCount: image.length,
                      pagination: SwiperPagination(
                        alignment: Alignment.bottomCenter,
                        margin: EdgeInsets.only(bottom: 10),
                        builder: SwiperCustomPagination(
                          builder: (context, config) {
                            return _HomeBannerSliderIndicator(
                              activeIndex: config.activeIndex,
                              itemCount: config.itemCount,
                            );
                          },
                        ),
                      ),
                      // 隐藏左右按钮
                      control: null,
                    ),
                  ),
                ),
              ),
              if (isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (error != null)
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: _HomeErrorState(
                    onRetry: () {
                      ref.read(homeDataControllerProvider.notifier).retry();
                    },
                  ),
                )
              else if (isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppEmptyState(message: context.l10n.emptyNoDramas),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(13, 2, 12, 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.crossAxisExtent <= 0) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
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
                        childCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          return _HomeDramaCard(
                            key: ValueKey('home_drama_card_$index'),
                            data: item,
                            coverCacheWidth: coverCacheWidth,
                            onTap: () {
                              final tappedAt = DateTime.now();
                              context.push(
                                RoutePaths.playerLocation(
                                  dramaId: item.id,
                                  episodeId: '1',
                                  trigger: 'home_card_tap',
                                  userActionAtMs:
                                      tappedAt.millisecondsSinceEpoch,
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
                  isLoading: homeDataState.isLoadingMore,
                  hasMore: selectedRemoteTab?.hasMoreDramas == true,
                  error: homeDataState.loadMoreError,
                  onRetry: () {
                    final tab = selectedRemoteTab;
                    if (tab != null) {
                      ref
                          .read(homeDataControllerProvider.notifier)
                          .loadMoreTab(tab.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBannerSliderIndicator extends StatelessWidget {
  const _HomeBannerSliderIndicator({
    required this.activeIndex,
    required this.itemCount,
  });

  final int activeIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final alignmentX = itemCount <= 1
        ? 0.0
        : -1.0 + (2.0 * activeIndex / (itemCount - 1));

    return Container(
      width: 72,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment(alignmentX, 0),
        child: Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _HomeTitleBar extends ConsumerStatefulWidget {
  const _HomeTitleBar();

  @override
  ConsumerState<_HomeTitleBar> createState() => _HomeTitleBarState();
}

class _HomeTitleBarState extends ConsumerState<_HomeTitleBar> {
  static const _recommendationInterval = Duration(seconds: 8);

  Timer? _recommendationTimer;
  List<String> _recommendationKeywords = const [];
  int _recommendedKeywordIndex = 0;

  @override
  void dispose() {
    _recommendationTimer?.cancel();
    super.dispose();
  }

  void _updateRecommendationKeywords(List<String> keywords) {
    if (_sameKeywords(_recommendationKeywords, keywords)) return;
    _recommendationKeywords = List.unmodifiable(keywords);
    _recommendedKeywordIndex = 0;
    _recommendationTimer?.cancel();
    if (_recommendationKeywords.length < 2) return;
    _recommendationTimer = Timer.periodic(_recommendationInterval, (_) {
      if (!mounted || _recommendationKeywords.isEmpty) return;
      setState(() {
        _recommendedKeywordIndex =
            (_recommendedKeywordIndex + 1) % _recommendationKeywords.length;
      });
    });
  }

  bool _sameKeywords(List<String> previous, List<String> next) {
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != next[index]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isMember = ref.watch(entitlementControllerProvider).isMember;
    final keywords = ref.watch(
      homeDataControllerProvider.select((state) => state.hotSearchKeywords),
    );
    _updateRecommendationKeywords(keywords);
    final recommendation = keywords.isEmpty
        ? ''
        : keywords[_recommendedKeywordIndex % keywords.length];

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.push<void>(RoutePaths.search);
            },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              decoration: BoxDecoration(
                color: Color(0XFF3A3A3A).withValues(alpha: 0.6),
                border: Border.all(
                  width: 0.5,
                  color: Color(0XFF949494).withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    "assets/images/player/search.svg",
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      Color(0XFFAFAFAF),
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previousChildren, ?currentChild],
                        );
                      },
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: animation.drive(
                            Tween<Offset>(
                              begin: const Offset(0, 0.85),
                              end: Offset.zero,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: Text(
                        recommendation.isEmpty
                            ? context.l10n.searchKeyWordHint
                            : recommendation,
                        key: ValueKey(recommendation),
                        maxLines: 1,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0XFFAFAFAF),
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          key: const ValueKey('home_vip_entry'),
          onTap: () => context.push(
            isMember
                ? RoutePaths.myMember
                : RoutePaths.membershipLocation(returnToProfile: true),
          ),
          child: const Padding(
            padding: EdgeInsets.only(right: 1, left: 7),
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
      'assets/images/home/vip_crown_figma.png',
      width: 36,
      height: 34,
      cacheWidth: (36 * MediaQuery.devicePixelRatioOf(context)).round(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
    );
  }
}

class _HomeFixedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HomeFixedHeaderDelegate({
    required this.tabs,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final List<DramaCategory> tabs;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  double get minExtent => 108;

  @override
  double get maxExtent => 108;

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
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(17, 18, 17, 2),
              child: _HomeTitleBar(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 13, 0, 0),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tabs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 31),
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
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeFixedHeaderDelegate oldDelegate) {
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
    super.key,
  });

  final Drama data;
  final int coverCacheWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibleTags = data.tags;

    return Material(
      color: Color(0XFF1C1821),
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
                  _HomeCoverImage(
                    resource: data.coverResource,
                    cacheWidth: coverCacheWidth,
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
                      color: AppColors.textOnCard,
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  if (visibleTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 16,
                      child: _HomeTagsRow(tags: visibleTags),
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

class _HomeCoverImage extends StatelessWidget {
  const _HomeCoverImage({required this.resource, required this.cacheWidth});

  final MediaResource resource;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (resource.isNetwork) {
      return AppCachedNetworkImage(
        imageUrl: resource.value,
        cacheWidth: cacheWidth,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.low,
      );
    }

    return Image.asset(
      resource.value,
      cacheWidth: cacheWidth,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.low,
    );
  }
}

class _ExclusiveBadge extends StatelessWidget {
  const _ExclusiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 60,
      // height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFEEBD), Color(0xFFFDB849)],
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Text(
        context.l10n.exclusive,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF652400),
          fontSize: 11,
          fontWeight: FontWeight.w500,
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
        // const Icon(Icons.play_arrow, color: AppColors.textPrimary, size: 14),
        Image.asset(
          'assets/images/home/home_views.png',
          width: 8,
          height: 8,
          cacheWidth: (8 * MediaQuery.devicePixelRatioOf(context)).round(),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textOnCard,
            fontWeight: FontWeight.normal,
            fontSize: 9,
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

  static const horizontalPadding = 12.0;

  static TextStyle? textStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0xFFE3E3E3).withValues(alpha: 0.6),
      fontSize: 9,
      height: 1.3,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x3DD9D9D9).withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: textStyle(context),
      ),
    );
  }
}

class _HomeTagsRow extends StatelessWidget {
  const _HomeTagsRow({required this.tags});

  static const _gap = 8.0;

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleTags = _visibleTagsForWidth(context, constraints.maxWidth);
        return Row(
          children: [
            for (final tag in visibleTags.indexed) ...[
              _HomeTag(label: tag.$2),
              if (tag.$1 != visibleTags.length - 1) const SizedBox(width: _gap),
            ],
          ],
        );
      },
    );
  }

  List<String> _visibleTagsForWidth(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return const [];
    }

    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final style = _HomeTag.textStyle(context);
    final visibleTags = <String>[];
    var usedWidth = 0.0;

    for (final tag in tags) {
      final tagWidth =
          _measureTextWidth(
            tag,
            style: style,
            textDirection: textDirection,
            textScaler: textScaler,
          ) +
          _HomeTag.horizontalPadding;
      final nextWidth = usedWidth + (visibleTags.isEmpty ? 0 : _gap) + tagWidth;
      if (nextWidth > maxWidth) {
        break;
      }
      visibleTags.add(tag);
      usedWidth = nextWidth;
    }

    return visibleTags;
  }

  double _measureTextWidth(
    String text, {
    required TextStyle? style,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    return painter.width;
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
          context.l10n.networkError,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        AppRetryButton(onPressed: onRetry, label: context.l10n.retry),
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
              ? AppRetryButton(onPressed: onRetry, label: context.l10n.retry)
              : Text(
                  hasMore ? '' : context.l10n.feedNoMore,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
        ),
      ),
    );
  }
}
