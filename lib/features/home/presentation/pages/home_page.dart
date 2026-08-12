import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_swiper_plus/flutter_swiper_plus.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../core/adjust/adjust_event_reporter_provider.dart';
import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/drama_card_exposure.dart';
import '../../../../core/analytics/analytics_page_context.dart';
import '../../../../core/analytics/analytics_page_tracker.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/analytics_entry_source.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/network/api_client_provider.dart';
import '../../../../core/notification/startup_notification_permission_reporter.dart';
import '../../../../features/drama/domain/drama.dart';
import '../../../../features/entitlement/application/entitlement_controller.dart';
import '../../../../features/player/application/player_entry_preload_coordinator.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/media/media_resource.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../../../shared/url/external_url_launcher.dart';
import '../../application/home_data_controller.dart';
import '../../application/home_banner_config_controller.dart';
import '../../application/home_banner_analytics.dart';
import '../../application/home_remote_data_provider.dart';
import '../../data/dto/home_banner_response_dto.dart';
import 'home_preload_candidate.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final Object _dramaExposureSession = Object();
  final _scrollController = ScrollController();
  final Map<int, double> _tabScrollOffsets = <int, double>{};
  int _remoteDataSelectedIndex = 0; // 远程数据的选中分类索引
  int _lastScrollToTopRequest = 0; // 跟踪上次的滚动请求计数
  ProviderSubscription<int>? _scrollToTopListener; // 监听滚动请求的订阅
  ProviderSubscription<bool>? _accessTokenListener;
  ProviderSubscription<AnalyticsPageContext>? _homePageSessionListener;
  late final HomeBannerExposureTracker _bannerExposureTracker;
  bool _notificationPermissionCheckScheduled = false;
  bool _notificationPermissionChecked = false;
  bool _homeFirstViewCheckScheduled = false;
  bool _bannerNavigationInProgress = false;
  String? _homeVisiblePreloadDramaId;
  final ValueNotifier<int> _cardVisibilityRevision = ValueNotifier(0);
  Timer? _cardVisibilityDebounce;
  final Map<String, HomePreloadCandidate> _pendingVisibleCandidates = {};
  Timer? _candidateSelectionDebounce;

  @override
  void initState() {
    super.initState();
    _bannerExposureTracker = HomeBannerExposureTracker(
      analytics: ref.read(analyticsServiceProvider),
    );
    _homePageSessionListener = ref.listenManual(analyticsPageContextProvider, (
      previous,
      next,
    ) {
      if (next.currentPage == AnalyticsPageNames.home &&
          previous?.currentPage != AnalyticsPageNames.home) {
        _bannerExposureTracker.beginPageSession();
      }
    }, fireImmediately: true);
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
    DramaCardExposure.releasePageSession(_dramaExposureSession);
    // 取消滚动请求的监听
    _scrollToTopListener?.close();
    _accessTokenListener?.close();
    _homePageSessionListener?.close();
    _cardVisibilityDebounce?.cancel();
    _candidateSelectionDebounce?.cancel();
    _cardVisibilityRevision.dispose();

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

  void _reportHomeFirstViewAfterDisplay() {
    if (_homeFirstViewCheckScheduled) return;
    _homeFirstViewCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeFirstViewCheckScheduled = false;
      if (!mounted) return;

      final remoteData = ref.read(homeRemoteDataProvider);
      final homeDataState = ref.read(homeDataControllerProvider);
      final isStillLoading =
          homeDataState.isLoading ||
          (remoteData == null && homeDataState.error == null);
      if (isStillLoading || homeDataState.error != null) return;

      unawaited(ref.read(adjustEventReporterProvider).reportHomeFirstView());
    });
  }

  void _onScroll() {
    // Cards evaluate after scrolling settles, then apply their own 400ms dwell
    // rule. This avoids starting a candidate for every card passed at speed.
    _cardVisibilityDebounce?.cancel();
    _cardVisibilityDebounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _cardVisibilityRevision.value += 1;
    });
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

  void _preloadStableVisibleDrama(Drama drama, double visibleFraction) {
    if (!mounted) return;
    // 首屏中可能有多张卡在同一帧同时达到 50%。先收集极短的一批曝光，再选择
    // 可见比例最高的一张，不能按 widget callback 的偶然顺序连续启动多部详情请求。
    _pendingVisibleCandidates[drama.id] = HomePreloadCandidate(
      drama: drama,
      visibleFraction: visibleFraction,
    );
    _candidateSelectionDebounce?.cancel();
    _candidateSelectionDebounce = Timer(const Duration(milliseconds: 32), () {
      if (!mounted || _pendingVisibleCandidates.isEmpty) return;
      final candidate = _pendingVisibleCandidates.values.reduce(
        (best, value) =>
            value.visibleFraction > best.visibleFraction ? value : best,
      );
      _pendingVisibleCandidates.clear();
      if (_homeVisiblePreloadDramaId == candidate.drama.id) return;
      _homeVisiblePreloadDramaId = candidate.drama.id;
      debugPrint(
        '[player-entry-preload] home selected candidate '
        'dramaId=${candidate.drama.id} '
        'visiblePercent=${(candidate.visibleFraction * 100).round()}',
      );
      ref
          .read(playerEntryPreloadCoordinatorProvider.notifier)
          .prepareVisibleCandidate(
            dramaId: candidate.drama.id,
            trigger: 'home_visible_candidate',
          );
    });
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

      unawaited(
        ref
            .read(analyticsServiceProvider)
            .track(
              AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                'element_name': 'home_category_tab',
                'category_id': remoteData.categories[index].id,
                'position': index + 1,
              }),
            ),
      );
      _saveCurrentTabScrollOffset(remoteData);
      setState(() {
        _remoteDataSelectedIndex = index;
        _homeVisiblePreloadDramaId = null;
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
    final bannerState = ref.watch(homeBannerConfigControllerProvider);

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

    if (!isLoading && error == null) {
      _reportHomeFirstViewAfterDisplay();
    }

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
              if (bannerState.visibleBanners.isNotEmpty)
                SliverToBoxAdapter(
                  child: _HomeRemoteBannerCarousel(
                    banners: bannerState.visibleBanners,
                    onImageError: (bannerId) => ref
                        .read(homeBannerConfigControllerProvider.notifier)
                        .disableBanner(bannerId),
                    onTap: _handleBannerTap,
                    onVisible: _trackBannerExposure,
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

                          return DramaCardExposure(
                            pageSession: _dramaExposureSession,
                            analytics: ref.read(analyticsServiceProvider),
                            dramaId: item.id,
                            position: index + 1,
                            categoryId: selectedRemoteTab?.id.toString() ?? '',
                            child: _HomeDramaCard(
                              key: ValueKey('home_drama_card_${item.id}'),
                              data: item,
                              coverCacheWidth: coverCacheWidth,
                              onStableVisible: (visibleFraction) =>
                                  _preloadStableVisibleDrama(
                                    item,
                                    visibleFraction,
                                  ),
                              visibilityRevision: _cardVisibilityRevision,
                              onTap: () {
                                unawaited(
                                  ref
                                      .read(analyticsServiceProvider)
                                      .track(
                                        AnalyticsEvent(
                                          AnalyticsDefinitions.elementClick,
                                          {
                                            'element_name': 'drama_card',
                                            'drama_id': item.id,
                                            'position': index + 1,
                                            'category_id':
                                                selectedRemoteTab?.id
                                                    .toString() ??
                                                '',
                                          },
                                        ),
                                      ),
                                );
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
                            ),
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

  Future<void> _handleBannerTap(HomeBannerDto banner) async {
    if (_bannerNavigationInProgress) return;
    final jumpType = banner.jumpType.trim().toLowerCase();
    if (jumpType == 'none') return;
    _bannerNavigationInProgress = true;
    try {
      final analyticsBanner = HomeBannerAnalyticsItem(
        bannerId: banner.bannerId,
        targetType: jumpType,
        targetDramaId: jumpType == 'drama' ? banner.jumpParam : null,
      );
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .track(
              AnalyticsEvent(
                AnalyticsDefinitions.elementClick,
                analyticsBanner.toEventParameters(),
              ),
            ),
      );
      final value = banner.jumpParam.trim();
      switch (jumpType) {
        case 'internal_h5':
          final url = banner.normalizedH5Url;
          if (url == null) {
            return;
          }
          prepareHomeBannerEntrySource(
            ref.read(analyticsEntrySourceProvider.notifier),
            analyticsBanner,
          );
          if (mounted) {
            context.push(RoutePaths.webviewLocation(url: url));
          }
          return;
        case 'external_h5':
          final url = banner.normalizedH5Url;
          if (url != null) {
            await ref.read(externalUrlLauncherProvider).open(url);
          }
          return;
        case 'drama':
          if (value.isEmpty || !RegExp(r'^\d+$').hasMatch(value)) {
            return;
          }
          prepareHomeBannerEntrySource(
            ref.read(analyticsEntrySourceProvider.notifier),
            analyticsBanner,
          );
          if (mounted) {
            context.push(
              RoutePaths.playerLocation(
                dramaId: value,
                episodeId: '1',
                trigger: 'home_banner',
                userActionAtMs: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
          return;
        case 'app_page':
          _openBannerAppPage(value, analyticsBanner);
          return;
      }
    } finally {
      _bannerNavigationInProgress = false;
    }
  }

  void _trackBannerExposure(HomeBannerDto banner) {
    if (!mounted) return;
    final targetType = banner.jumpType.trim().toLowerCase();
    unawaited(
      _bannerExposureTracker.trackVisible(
        HomeBannerAnalyticsItem(
          bannerId: banner.bannerId,
          targetType: targetType,
          targetDramaId: targetType == 'drama' ? banner.jumpParam.trim() : null,
        ),
      ),
    );
  }

  void _openBannerAppPage(String pageCode, HomeBannerAnalyticsItem banner) {
    final location = switch (pageCode) {
      'home' => RoutePaths.home,
      'recommend_tab' => RoutePaths.forYou,
      'member_tab' => RoutePaths.member,
      'member_open' => RoutePaths.membership,
      'recharge' => RoutePaths.store,
      'reward_coin' => RoutePaths.rewardsLocation(),
      'member_point' => RoutePaths.rewardsLocation(
        tab: RoutePaths.memberPointsTab,
      ),
      _ => null,
    };
    if (location == null || !mounted) return;
    prepareHomeBannerEntrySource(
      ref.read(analyticsEntrySourceProvider.notifier),
      banner,
    );
    if (pageCode == 'member_open' || pageCode == 'recharge') {
      context.push(location);
    } else {
      context.go(location);
    }
  }
}

class _HomeRemoteBannerCarousel extends StatefulWidget {
  const _HomeRemoteBannerCarousel({
    required this.banners,
    required this.onImageError,
    required this.onTap,
    required this.onVisible,
  });

  final List<HomeBannerDto> banners;
  final ValueChanged<String> onImageError;
  final ValueChanged<HomeBannerDto> onTap;
  final ValueChanged<HomeBannerDto> onVisible;

  @override
  State<_HomeRemoteBannerCarousel> createState() =>
      _HomeRemoteBannerCarouselState();
}

class _HomeRemoteBannerCarouselState extends State<_HomeRemoteBannerCarousel> {
  Timer? _visibilityTimer;
  Timer? _visibilityPoller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateVisibility());
    _visibilityPoller = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _evaluateVisibility(),
    );
  }

  @override
  void didUpdateWidget(covariant _HomeRemoteBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activeIndex >= widget.banners.length) {
      _activeIndex = 0;
      _resetVisibilityTimer();
    }
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _visibilityPoller?.cancel();
    super.dispose();
  }

  void _onIndexChanged(int index) {
    if (_activeIndex == index) return;
    setState(() => _activeIndex = index);
    _resetVisibilityTimer();
    _evaluateVisibility();
  }

  void _resetVisibilityTimer() {
    _visibilityTimer?.cancel();
    _visibilityTimer = null;
  }

  void _evaluateVisibility() {
    if (!mounted || widget.banners.isEmpty || !_isAtLeastHalfVisible()) {
      _resetVisibilityTimer();
      return;
    }
    _visibilityTimer ??= Timer(const Duration(seconds: 1), () {
      _visibilityTimer = null;
      if (!mounted || !_isAtLeastHalfVisible()) return;
      final index = _activeIndex % widget.banners.length;
      widget.onVisible(widget.banners[index]);
    });
  }

  bool _isAtLeastHalfVisible() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final viewport = Offset.zero & MediaQuery.sizeOf(context);
    final visible = rect.intersect(viewport);
    if (rect.isEmpty || visible.isEmpty) return false;
    return visible.width * visible.height >= rect.width * rect.height * .5;
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('home_remote_banner_carousel'),
    height: 200,
    margin: const EdgeInsets.only(bottom: 10, left: 14, right: 14),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Swiper(
        autoplay: widget.banners.length > 1,
        autoplayDelay: 3000,
        itemCount: widget.banners.length,
        itemBuilder: (context, index) {
          final banner = widget.banners[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onTap(banner),
            child: AppCachedNetworkImage(
              imageUrl: banner.imageUrl,
              fit: BoxFit.fill,
              onError: () => widget.onImageError(banner.bannerId),
            ),
          );
        },
        onIndexChanged: _onIndexChanged,
        pagination: SwiperPagination(
          alignment: Alignment.bottomCenter,
          margin: const EdgeInsets.only(bottom: 10),
          builder: SwiperCustomPagination(
            builder: (context, config) => _HomeBannerSliderIndicator(
              activeIndex: config.activeIndex,
              itemCount: config.itemCount,
            ),
          ),
        ),
        control: null,
      ),
    ),
  );
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
    const trackWidth = 72.0;
    final count = itemCount < 1 ? 1 : itemCount;
    final index = activeIndex.clamp(0, count - 1).toDouble();
    final alignmentX = count <= 1 ? 0.0 : -1.0 + (2.0 * index / (count - 1));
    final activeWidth = trackWidth / count;

    return Container(
      width: trackWidth,
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
          width: activeWidth,
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
          onTap: () {
            if (!isMember) {
              unawaited(
                ref
                    .read(analyticsServiceProvider)
                    .track(
                      const AnalyticsEvent(AnalyticsDefinitions.elementClick, {
                        'element_name': 'vip_entry',
                      }),
                    ),
              );
            }
            context.push(
              isMember
                  ? RoutePaths.myMember
                  : RoutePaths.membershipLocation(returnToProfile: true),
            );
          },
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

class _HomeDramaCard extends StatefulWidget {
  const _HomeDramaCard({
    required this.data,
    required this.coverCacheWidth,
    required this.onTap,
    required this.onStableVisible,
    required this.visibilityRevision,
    super.key,
  });

  final Drama data;
  final int coverCacheWidth;
  final VoidCallback onTap;
  final ValueChanged<double> onStableVisible;
  final ValueListenable<int> visibilityRevision;

  @override
  State<_HomeDramaCard> createState() => _HomeDramaCardState();
}

class _HomeDramaCardState extends State<_HomeDramaCard> {
  Timer? _stableVisibleTimer;
  var _didNotifyStableVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _evaluateVisibility();
    });
    widget.visibilityRevision.addListener(_evaluateVisibility);
  }

  @override
  void dispose() {
    _stableVisibleTimer?.cancel();
    widget.visibilityRevision.removeListener(_evaluateVisibility);
    super.dispose();
  }

  void _evaluateVisibility() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    if (!_isAtLeastHalfVisible()) {
      _stableVisibleTimer?.cancel();
      _stableVisibleTimer = null;
      _didNotifyStableVisible = false;
      return;
    }
    if (_didNotifyStableVisible || _stableVisibleTimer != null) return;

    _stableVisibleTimer = Timer(const Duration(milliseconds: 400), () {
      _stableVisibleTimer = null;
      if (!mounted || _didNotifyStableVisible || !_isAtLeastHalfVisible()) {
        return;
      }
      _didNotifyStableVisible = true;
      widget.onStableVisible(_visibleFraction());
    });
  }

  bool _isAtLeastHalfVisible() {
    return _visibleFraction() >= 0.5;
  }

  double _visibleFraction() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return 0;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final viewport = MediaQuery.sizeOf(context);
    final visibleHeight =
        math.min(topLeft.dy + renderObject.size.height, viewport.height) -
        math.max(topLeft.dy, 0);
    return (visibleHeight / renderObject.size.height).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final visibleTags = widget.data.tags;

    return Material(
      color: Color(0XFF1C1821),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: widget.data.coverAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HomeCoverImage(
                    resource: widget.data.coverResource,
                    cacheWidth: widget.coverCacheWidth,
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
                  if (widget.data.isExclusive)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: _ExclusiveBadge(),
                    ),
                  Positioned(
                    right: 9,
                    bottom: 10,
                    child: _ViewCount(label: widget.data.viewCountLabel),
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
                    widget.data.title,
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
