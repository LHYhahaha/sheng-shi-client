import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../core/analytics/analytics_definition.dart';
import '../../../../core/analytics/drama_card_exposure.dart';
import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/logging/app_log.dart' as developer;
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../core/utils/text_over_ellipsis.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/app_compact_drama_grid.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_load_more_indicator.dart';
import '../../../../shared/widgets/app_peg_top_loader.dart';
import '../../../../shared/widgets/app_retry_button.dart';
import '../../../search/domain/search_rankings.dart';
import '../../../player/application/player_entry_preload_coordinator.dart';
import '../../application/my_list_hot_plays_controller.dart';
import '../../application/my_list_controller.dart';
import '../../domain/my_list_item.dart';

/// My list 页面。
///
/// 页面只负责组装 header/tab/list/slidable 和 shell navigation 显隐；列表数据、编辑态、
/// 选择集合、删除和 open slidable 都由 MyListController 管理。两个 tab 都支持批量编辑
/// 和单行滑动删除，但两种交互互斥（编辑模式下禁用滑动删除）。
class MyListPage extends ConsumerStatefulWidget {
  const MyListPage({super.key});

  @override
  ConsumerState<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends ConsumerState<MyListPage> {
  AppShellBottomNavigationVisible? _shellChrome;
  late final ScrollController _scrollController;
  final _dramaExposureSession = Object();
  bool _didTriggerLoadMoreNearEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    // 在 initState 中延迟初始化 ref 相关的东西
    Future.microtask(() {
      if (mounted) {
        _shellChrome = ref.read(
          appShellBottomNavigationVisibleProvider.notifier,
        );
      }
    });
  }

  @override
  void dispose() {
    DramaCardExposure.releasePageSession(_dramaExposureSession);
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _shellChrome?.show();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    // 推荐区仅在所有分页数据加载完成后展示，因此按普通列表的阈值加载下一页。
    // 这样新列表项不会插入到用户正在浏览的推荐区之前，造成内容闪现或跳动。
    if (_scrollController.position.extentAfter > 240) {
      _didTriggerLoadMoreNearEnd = false;
      return;
    }
    if (_didTriggerLoadMoreNearEnd) {
      return;
    }
    final state = ref.read(myListControllerProvider);
    if (!state.canLoadMore) {
      return;
    }
    _didTriggerLoadMoreNearEnd = true;
    ref.read(myListControllerProvider.notifier).loadMore();
  }

  void _scheduleFillShortListCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final state = ref.read(myListControllerProvider);
      if (!state.canLoadMore) {
        return;
      }
      if (state.items.isEmpty) {
        _didTriggerLoadMoreNearEnd = false;
        ref.read(myListControllerProvider.notifier).refreshCurrentTabInPlace();
        return;
      }
      if (!_scrollController.hasClients) {
        return;
      }

      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) {
        _didTriggerLoadMoreNearEnd = false;
        ref.read(myListControllerProvider.notifier).refreshCurrentTabInPlace();
      }
    });
  }

  Future<void> _deleteSelectedAndFillIfShort(
    MyListController controller,
  ) async {
    await controller.deleteSelected();
    _scheduleFillShortListCheck();
  }

  Future<void> _deleteItemAndFillIfShort(
    MyListController controller,
    int dramaId,
  ) async {
    await controller.deleteItem(dramaId);
    _scheduleFillShortListCheck();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(myListControllerProvider);
    final hotPlaysState = ref.watch(myListHotPlaysControllerProvider);
    final controller = ref.read(myListControllerProvider.notifier);

    // My List tab 由 StatefulShell 保活。重新激活时保留旧内容并后台刷新；
    // 只有首次进入或上一次加载失败才展示完整 loading。
    ref.listen(appShellCurrentTabIndexProvider, (previous, current) {
      if (current == AppShellDestinations.myListIndex && previous != current) {
        _didTriggerLoadMoreNearEnd = false;
        developer.log('MyList tab activated, refreshing data silently');
        controller.refreshSilently();
        ref.read(myListHotPlaysControllerProvider.notifier).load();
      }
    });
    ref.listen(
      myListControllerProvider.select(
        (state) => (state.selectedTab, state.isLoading),
      ),
      (previous, next) {
        if (previous?.$1 != next.$1 || next.$2) {
          _didTriggerLoadMoreNearEnd = false;
        }
      },
    );
    ref.listen(
      myListControllerProvider.select(
        (state) => (
          state.items.length,
          state.nextPageToken,
          state.isCollectionEditing,
          state.isLoading,
          state.isLoadingMore,
          state.error,
          state.loadMoreError,
        ),
      ),
      (previous, next) {
        final didListShrink = previous != null && next.$1 < previous.$1;
        final didBecomeLoadable =
            previous?.$3 == true && !next.$3 ||
            previous?.$4 == true && !next.$4 ||
            previous?.$5 == true && !next.$5 ||
            previous?.$2 != next.$2;
        if (didListShrink || didBecomeLoadable) {
          _scheduleFillShortListCheck();
        }
      },
    );
    ref.listen(
      myListControllerProvider.select((state) => state.isCollectionEditing),
      (previous, next) {
        // 批量编辑时隐藏 shell bottom navigation，给底部删除栏让位。
        // dispose 时会强制 show，避免从编辑态离开页面后全局导航永久隐藏。
        if (next) {
          _shellChrome?.hide();
        } else {
          _shellChrome?.show();
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Stack(
          children: [
            SlidableAutoCloseBehavior(
              closeWhenOpened: true,
              closeWhenTapped: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MyListHeader(
                    choosing: state.isCollectionEditing,
                    canEdit: state.canEditCollection,
                    allSelected: state.areAllItemsSelected,
                    onEdit: controller.enterCollectionEdit,
                    onCancel: controller.cancelCollectionEdit,
                    onSelectAll: controller.toggleSelectAll,
                  ),
                  _MyListTabs(
                    selectedTab: state.selectedTab,
                    onSelected: _selectMyListTab,
                  ),
                  Expanded(
                    child: _buildBody(
                      l10n,
                      state,
                      hotPlaysState.dramas,
                      controller,
                    ),
                  ),
                ],
              ),
            ),
            if (state.isCollectionEditing)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _DeleteBar(
                  count: state.selectedCount,
                  onDelete: () => _deleteSelectedAndFillIfShort(controller),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectMyListTab(MyListTab tab) {
    if (ref.read(myListControllerProvider).selectedTab == tab) {
      return;
    }
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'favorite_tab',
              'favorite_tab': switch (tab) {
                MyListTab.collection => 'watching',
                MyListTab.play => 'history',
              },
            }),
          ),
    );
    unawaited(ref.read(myListControllerProvider.notifier).selectTab(tab));
  }

  Widget _buildBody(
    AppLocalizations l10n,
    MyListState state,
    List<SearchRankDrama> hotPlays,
    MyListController controller,
  ) {
    if (state.isLoading) {
      return const Center(child: AppPegTopLoader());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.networkError,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            AppRetryButton(onPressed: controller.retry, label: l10n.retry),
          ],
        ),
      );
    }

    final children = <Widget>[];
    // 只有确认没有下一页、且当前没有分页请求/错误时才展示推荐区。否则用户快速
    // 下滑时会先看到推荐区，待下一页返回后又被新条目推到下方，形成闪现。
    final shouldShowHotPlays =
        hotPlays.length >= MyListHotPlaysController.maxItems &&
        !state.isLoadingMore &&
        state.nextPageToken == null &&
        state.loadMoreError == null;
    if (state.isEmpty) {
      final emptyText = state.selectedTab == MyListTab.collection
          ? l10n.myListEmptyFollowing
          : l10n.myListEmptyHistory;
      children.add(
        SizedBox(
          height: 220.w,
          child: _EmptyMyList(description: emptyText),
        ),
      );
    } else {
      for (final (index, item) in state.items.indexed) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: 16.w,
              right: state.isCollectionEditing ? 4.w : 0,
            ),
            child: DramaCardExposure(
              pageSession: _dramaExposureSession,
              analytics: ref.read(analyticsServiceProvider),
              dramaId: item.dramaId.toString(),
              position: index + 1,
              cardScene: state.selectedTab == MyListTab.collection
                  ? 'favorite_watching'
                  : 'favorite_history',
              child: _MyListRowSwipeAction(
                // 两个 tab 都支持左滑删除，但编辑模式下禁用
                enabled: !state.isCollectionEditing,
                item: item,
                onDelete: () =>
                    _deleteItemAndFillIfShort(controller, item.dramaId),
                onOpened: () => controller.openPlayItem(item.dramaId),
                onClosed: () => controller.closeOpenPlayItem(item.dramaId),
                child: _MyListRow(
                  item: item,
                  choosing: state.isCollectionEditing,
                  selected: state.selectedIds.contains(item.dramaId),
                  onTap: state.isCollectionEditing
                      ? () => controller.toggleSelection(item.dramaId)
                      : () => _openMyListItem(
                          l10n,
                          state,
                          controller,
                          item,
                          position: index + 1,
                        ),
                ),
              ),
            ),
          ),
        );
      }
      final needsLoadMoreFooter =
          !shouldShowHotPlays ||
          state.isLoadingMore ||
          state.nextPageToken != null ||
          state.loadMoreError != null;
      if (needsLoadMoreFooter) {
        children.add(
          _MyListLoadMoreFooter(
            isLoading: state.isLoadingMore,
            hasMore: state.nextPageToken != null,
            error: state.loadMoreError,
            onRetry: () => controller.loadMore(retry: true),
          ),
        );
      }
    }

    // 批量编辑时只保留待删除列表，避免推荐标题和内容出现在多选区域下方。
    if (shouldShowHotPlays && !state.isCollectionEditing) {
      children.add(
        _HotPlaysSection(
          dramas: hotPlays,
          pageSession: _dramaExposureSession,
          analytics: ref.read(analyticsServiceProvider),
          onTap: (drama, position) =>
              _openHotPlay(controller, drama, position: position),
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        16.w,
        15.w,
        0,
        state.isCollectionEditing
            ? 108.w + MediaQuery.viewPaddingOf(context).bottom
            : 24.w,
      ),
      children: children,
    );
  }

  Future<void> _openMyListItem(
    AppLocalizations l10n,
    MyListState state,
    MyListController controller,
    MyListItem item, {
    required int position,
  }) async {
    if (item.dramaStatus == 2) {
      ref.read(appToastProvider).info(l10n.myListDramaOffShelf);
      return;
    }
    controller.closeAnyOpenPlayItem();
    final isCollection = state.selectedTab == MyListTab.collection;
    final episodeId = item.episodeId != null && item.episodeId! > 0
        ? item.episodeId.toString()
        : '1';
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'drama_card',
              'drama_id': item.dramaId.toString(),
              'position': position,
              'card_scene': isCollection
                  ? 'favorite_watching'
                  : 'favorite_history',
            }),
          ),
    );
    preparePlayerEntryPreload(
      context,
      dramaId: item.dramaId.toString(),
      episodeId: episodeId,
      trigger: isCollection ? 'my_list_collection_item' : 'play_history_item',
    );
    await context.push(
      RoutePaths.playerLocation(
        dramaId: item.dramaId.toString(),
        episodeId: episodeId,
        trigger: isCollection ? 'my_list_collection_item' : 'play_history_item',
      ),
    );
    await controller.refreshCurrentTabInPlace();
  }

  Future<void> _openHotPlay(
    MyListController controller,
    SearchRankDrama drama, {
    required int position,
  }) async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .track(
            AnalyticsEvent(AnalyticsDefinitions.elementClick, {
              'element_name': 'drama_card',
              'drama_id': drama.id,
              'position': position,
              'card_scene': 'favorite_recommend',
            }),
          ),
    );
    preparePlayerEntryPreload(
      context,
      dramaId: drama.id,
      episodeId: '1',
      trigger: 'my_list_hot_play_tap',
      resumeHint: playerEntryResumeHintFor(drama.watchProgress),
    );
    await context.push(
      RoutePaths.playerLocation(
        dramaId: drama.id,
        episodeId: '1',
        trigger: 'my_list_hot_play_tap',
        userActionAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await controller.refreshCurrentTabInPlace();
  }
}

class _HotPlaysSection extends StatelessWidget {
  const _HotPlaysSection({
    required this.dramas,
    required this.pageSession,
    required this.analytics,
    required this.onTap,
  });

  final List<SearchRankDrama> dramas;
  final Object pageSession;
  final AnalyticsService analytics;
  final void Function(SearchRankDrama drama, int position) onTap;

  @override
  Widget build(BuildContext context) {
    final hasTagRow = dramas.any((drama) => drama.tags.isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(top: 20.w, right: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.favoriteSectionHotRecommend,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.6),
              fontSize: 16.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12.w),
          AppCompactDramaGrid(
            itemCount: dramas.length,
            hasTagRow: hasTagRow,
            itemBuilder: (context, index) {
              final drama = dramas[index];
              return DramaCardExposure(
                pageSession: pageSession,
                analytics: analytics,
                dramaId: drama.id,
                position: index + 1,
                cardScene: 'favorite_recommend',
                child: AppCompactDramaCard(
                  coverUrl: drama.coverUrl,
                  title: drama.title,
                  tags: drama.tags,
                  topLeftOverlay: _HotPlayRankBadge(ranking: index + 1),
                  onTap: () => onTap(drama, index + 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HotPlayRankBadge extends StatelessWidget {
  const _HotPlayRankBadge({required this.ranking});

  final int ranking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24.w,
      height: 14.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _rankingColor(ranking),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(4.w)),
      ),
      child: Text(
        '$ranking',
        style: TextStyle(
          height: 1,
          color: Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _rankingColor(int value) => switch (value) {
    1 => const Color(0xFFFB4729),
    2 => const Color(0xFFFBB829),
    3 => const Color(0xFFFF007A),
    _ => const Color(0xFF424242),
  };
}

class _MyListLoadMoreFooter extends StatelessWidget {
  const _MyListLoadMoreFooter({
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
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 18.w),
        child: Center(
          child: isLoading
              ? const AppLoadMoreIndicator(padding: EdgeInsets.zero)
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

class _MyListHeader extends StatelessWidget {
  const _MyListHeader({
    required this.choosing,
    required this.canEdit,
    required this.allSelected,
    required this.onEdit,
    required this.onCancel,
    required this.onSelectAll,
  });

  final bool choosing;
  final bool canEdit;
  final bool allSelected;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showTrailing = choosing || canEdit;

    return SizedBox(
      height: 72.w,
      child: Stack(
        children: [
          if (choosing)
            Positioned(
              left: 0,
              right: 0,
              top: 27.w,
              child: Text(
                l10n.myListChoose,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            )
          else
            Positioned(
              left: 17.w,
              top: 24.w,
              child: Text(
                l10n.navMyList,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          if (choosing)
            Positioned(
              left: 16.w,
              top: 18.w,
              child: TextButton(
                onPressed: onSelectAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textDisabled,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(82.w, 36.w),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  allSelected ? l10n.myListDeselectAll : l10n.myListSelectAll,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0XFF909090),
                    height: 1.1,
                  ),
                ),
              ),
            ),
          if (showTrailing)
            Positioned(
              right: 16.w,
              top: choosing ? 18.w : 22.w,
              child: choosing
                  ? TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textDisabled,
                        padding: EdgeInsets.zero,
                        minimumSize: Size(58.w, 36.w),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.myListCancel,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: Color(0XFF909090),
                          height: 1.1,
                        ),
                      ),
                    )
                  : _HeaderMoreMenu(onEdit: onEdit),
            ),
        ],
      ),
    );
  }
}

class _HeaderMoreMenu extends StatelessWidget {
  const _HeaderMoreMenu({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return
    // PopupMenuButton<_HeaderMenuAction>(
    // onSelected: (action) {
    //   switch (action) {
    //     case _HeaderMenuAction.edit:
    //       onEdit();
    //   }
    // },
    // color: AppColors.surfacePanel,
    // elevation: 0,
    // offset: const Offset(-4, 34),
    // padding: EdgeInsets.zero,
    // splashRadius: 1,
    // tooltip: '',
    // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    // itemBuilder: (context) => [
    //   PopupMenuItem<_HeaderMenuAction>(
    //     value: _HeaderMenuAction.edit,
    //     height: 38,
    //     child: Text(
    //       context.l10n.edit,
    //       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    //         color: AppColors.textPrimary,
    //         fontSize: 14,
    //         fontWeight: FontWeight.w500,
    //       ),
    //     ),
    //   ),
    // ],
    GestureDetector(
      onTap: () => onEdit(),
      child: SvgPicture.asset(
        "assets/images/my_list/mylist_edit.svg",
        width: 24.w,
        height: 24.w,
      ),
    );
  }
}

class _MyListTabs extends StatelessWidget {
  const _MyListTabs({required this.selectedTab, required this.onSelected});

  final MyListTab selectedTab;
  final ValueChanged<MyListTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: 28.w,
      child: Stack(
        children: [
          Positioned(
            left: 16.w,
            top: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TabLabel(
                  text: l10n.myListCollectionTab,
                  active: selectedTab == MyListTab.collection,
                  onTap: () => onSelected(MyListTab.collection),
                ),
                SizedBox(width: 32.w),
                _TabLabel(
                  text: l10n.myListPlayTab,
                  active: selectedTab == MyListTab.play,
                  onTap: () => onSelected(MyListTab.play),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.divider,
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 28.w,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.normal,
                  height: 1.18,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 2.w,
                child: ColoredBox(
                  color: active ? AppColors.primary : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyListRowSwipeAction extends StatelessWidget {
  const _MyListRowSwipeAction({
    required this.enabled,
    required this.item,
    required this.onDelete,
    required this.onOpened,
    required this.onClosed,
    required this.child,
  });

  final bool enabled;
  final MyListItem item;
  final VoidCallback onDelete;
  final VoidCallback onOpened;
  final VoidCallback onClosed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    // 两个 tab 都支持左滑删除，但编辑模式下禁用该能力，避免同一行同时响应
    // 选择和滑动删除。当进入编辑模式时，已打开的 slidable 会自动关闭。
    return _SlidableOpenTracker(
      onOpened: onOpened,
      onClosed: onClosed,
      builder: (context, controller) => Slidable(
        key: ValueKey(item.dramaId),
        controller: controller,
        groupTag: 'my-list-items',
        closeOnScroll: true,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 56 / 359,
          dragDismissible: false,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(),
              autoClose: true,
              backgroundColor: AppColors.danger,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    "assets/images/my_list/delete_white.svg",
                    width: 18.w,
                    height: 18.w,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 3.w),
                  Text(
                    context.l10n.myListDelete,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _SlidableOpenTracker extends StatefulWidget {
  const _SlidableOpenTracker({
    required this.onOpened,
    required this.onClosed,
    required this.builder,
  });

  final VoidCallback onOpened;
  final VoidCallback onClosed;
  final Widget Function(BuildContext context, SlidableController controller)
  builder;

  @override
  State<_SlidableOpenTracker> createState() => _SlidableOpenTrackerState();
}

class _SlidableOpenTrackerState extends State<_SlidableOpenTracker>
    with SingleTickerProviderStateMixin {
  late final SlidableController _controller;
  ActionPaneType _lastPaneType = ActionPaneType.none;

  @override
  void initState() {
    super.initState();
    _controller = SlidableController(this)
      ..actionPaneType.addListener(_handleActionPaneChanged);
  }

  @override
  void dispose() {
    _controller.actionPaneType.removeListener(_handleActionPaneChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleActionPaneChanged() {
    final paneType = _controller.actionPaneType.value;
    if (paneType == _lastPaneType) {
      return;
    }

    _lastPaneType = paneType;
    // flutter_slidable 的打开状态在 controller 内部，业务层只需要知道“哪一行打开”。
    // 这里把状态同步回 MyListController，便于点击其他区域或删除后关闭旧行。
    if (paneType == ActionPaneType.none) {
      widget.onClosed();
    } else {
      widget.onOpened();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller);
  }
}

class _MyListRow extends StatelessWidget {
  const _MyListRow({
    required this.item,
    required this.choosing,
    required this.selected,
    required this.onTap,
  });

  final MyListItem item;
  final bool choosing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = SizedBox(
      height: 101.w,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (choosing) ...[
            SizedBox(
              width: 32.w,
              height: 101.w,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SelectionCircle(selected: selected),
              ),
            ),
          ],
          _CoverImage(
            assetPath: item.coverAssetPath,
            currentEpisode: item.currentEpisode,
            episodeCount: item.episodeCount,
          ),
          SizedBox(width: 12.w),
          Expanded(child: _RowCopy(item: item)),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.assetPath,
    required this.currentEpisode,
    required this.episodeCount,
  });

  final String assetPath;
  final int currentEpisode;
  final int episodeCount;

  @override
  Widget build(BuildContext context) {
    // 计算进度百分比，总宽度为 74
    final progress = episodeCount > 0
        ? (currentEpisode / episodeCount).clamp(0.0, 1.0)
        : 0.0;
    final progressWidth = 74.w * progress;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xs.w),
      child: Stack(
        children: [
          _buildCoverImage(assetPath),
          Positioned(
            left: 0,
            bottom: 0,
            child: ColoredBox(
              color: Color(0x33FFFFFF),
              child: SizedBox(width: 74.w, height: 2.w),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.primary,
              child: SizedBox(width: progressWidth, height: 2.w),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(String assetPath) {
    // 判断是否是网络 URL
    if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
      return AppCachedNetworkImage(
        imageUrl: assetPath,
        fit: BoxFit.cover,
        width: 74.w,
        height: 101.w,
        filterQuality: FilterQuality.medium,
      );
    }

    // 本地 asset
    return Image.asset(
      assetPath,
      width: 74.w,
      height: 101.w,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 74.w,
          height: 101.w,
          color: Colors.grey[800],
          child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        );
      },
    );
  }
}

class _RowCopy extends StatelessWidget {
  const _RowCopy({required this.item});

  final MyListItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 7.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          SizedBox(height: 9.w),
          Text(
            limitTextLines(item.introduction, 2),
            maxLines: 2,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
              children: [
                TextSpan(
                  text: context.l10n.myListEpisode(
                    item.currentEpisode.toString(),
                  ),
                  style: const TextStyle(color: AppColors.primary),
                ),
                TextSpan(
                  text:
                      ' / ${context.l10n.myListEpisode2(item.episodeCount.toString())}',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.w),
        ],
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  const _SelectionCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 20.w,
      height: 20.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15.w, color: Colors.white)
          : null,
    );
  }
}

class _DeleteBar extends StatelessWidget {
  const _DeleteBar({required this.count, required this.onDelete});

  final int count;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final bottomInset = isIos ? 0.0 : MediaQuery.viewPaddingOf(context).bottom;
    final contentHeight = isIos ? 84.w : 64.w;

    return ColoredBox(
      color: AppColors.surfacePanel,
      child: SizedBox(
        height: contentHeight + bottomInset,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: contentHeight,
              child: Center(
                child: TextButton.icon(
                  onPressed: enabled ? onDelete : null,
                  icon: SvgPicture.asset(
                    "assets/images/my_list/delete.svg",
                    width: 18.w,
                    height: 18.w,
                    fit: BoxFit.contain,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.42),
                  ),
                  // Icon(
                  //   Icons.delete_outline_rounded,
                  //   color: enabled
                  //       ? AppColors.textPrimary
                  //       : AppColors.textPrimary.withValues(alpha: 0.42),
                  //   size: 18,
                  // ),
                  label: Text('${context.l10n.myListDelete} ($count)'),
                  style: TextButton.styleFrom(
                    foregroundColor: enabled
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.42),
                    disabledForegroundColor: AppColors.textPrimary.withValues(
                      alpha: 0.42,
                    ),
                    textStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    overlayColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMyList extends StatelessWidget {
  const _EmptyMyList({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: AppEmptyState(
          message: description,
          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontSize: 12.sp,
            height: 16 / 12,
          ),
        ),
      ),
    );
  }
}
