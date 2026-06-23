import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/shell/app_shell.dart';
import '../../../../app/shell/app_shell_chrome.dart';
import '../../../../core/toast/app_toast_provider.dart';
import '../../../../core/utils/text_over_ellipsis.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_radii.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    // 在 initState 中延迟初始化 ref 相关的东西
    Future.microtask(() {
      if (mounted) {
        _shellChrome = ref.read(
          appShellBottomNavigationVisibleProvider.notifier,
        );
        ref.read(myListControllerProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _shellChrome?.show();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(myListControllerProvider);
    final controller = ref.read(myListControllerProvider.notifier);

    // 监听 Tab 索引变化，当切换到 MyList Tab 时刷新数据
    ref.listen(appShellCurrentTabIndexProvider, (previous, current) {
      // 当切换到 MyList Tab 时刷新数据
      if (current == AppShellDestinations.myListIndex && previous != current) {
        developer.log('MyList tab activated, reloading data');
        controller.load();
      }
    });
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
        bottom: false,
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
                    onEdit: controller.enterCollectionEdit,
                    onCancel: controller.cancelCollectionEdit,
                  ),
                  _MyListTabs(
                    selectedTab: state.selectedTab,
                    onSelected: controller.selectTab,
                  ),
                  Expanded(child: _buildBody(l10n, state, controller)),
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
                  onDelete: controller.deleteSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    MyListState state,
    MyListController controller,
  ) {
    if (state.isLoading) {
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: TextButton(
          onPressed: controller.retry,
          child: Text(
            l10n.feedLoadFailed,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (state.isEmpty) {
      final isCollection = state.selectedTab == MyListTab.collection;
      final emptyText = isCollection
          ? l10n.myListEmptyFollowing
          : l10n.myListEmptyHistory;
      return _EmptyMyList(description: emptyText);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        15,
        state.isCollectionEditing ? 4 : 0,
        state.isCollectionEditing
            ? 108 + MediaQuery.viewPaddingOf(context).bottom
            : 24,
      ),
      itemCount: state.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return _MyListRowSwipeAction(
          // 两个 tab 都支持左滑删除，但编辑模式下禁用
          enabled: !state.isCollectionEditing,
          item: item,
          onDelete: () => controller.deleteItem(item.dramaId),
          onOpened: () => controller.openPlayItem(item.dramaId),
          onClosed: () => controller.closeOpenPlayItem(item.dramaId),
          child: Padding(
            padding: EdgeInsets.zero,
            child: _MyListRow(
              item: item,
              choosing: state.isCollectionEditing,
              selected: state.selectedIds.contains(item.dramaId),
              onTap: state.isCollectionEditing
                  ? () => controller.toggleSelection(item.dramaId)
                  : () async {
                      // 检查短剧在架状态，已下架则提示且不跳转
                      if (item.dramaStatus == 2) {
                        ref
                            .read(appToastProvider)
                            .info(l10n.myListDramaOffShelf);
                        return;
                      }
                      controller.closeAnyOpenPlayItem();
                      // 播放历史项点击导航到播放器
                      if (item.episodeId != null) {
                        await context.push(
                          RoutePaths.playerLocation(
                            dramaId: item.dramaId.toString(),
                            episodeId: item.episodeId.toString(),
                            trigger: 'play_history_item',
                          ),
                        );
                        // 从播放器页面返回后，刷新当前tab的数据以获取最新排序
                        controller.load();
                      }
                    },
            ),
          ),
        );
      },
    );
  }
}

class _MyListHeader extends StatelessWidget {
  const _MyListHeader({
    required this.choosing,
    required this.canEdit,
    required this.onEdit,
    required this.onCancel,
  });

  final bool choosing;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showTrailing = choosing || canEdit;

    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          if (choosing)
            Positioned(
              left: 0,
              right: 0,
              top: 27,
              child: Text(
                l10n.myListChoose,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            )
          else
            Positioned(
              left: 17,
              top: 24,
              child: Text(
                l10n.navMyList,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          if (showTrailing)
            Positioned(
              right: 16,
              top: choosing ? 23 : 18,
              child: choosing
                  ? TextButton(
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textDisabled,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(58, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.myListCancel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
    return PopupMenuButton<_HeaderMenuAction>(
      onSelected: (action) {
        switch (action) {
          case _HeaderMenuAction.edit:
            onEdit();
        }
      },
      color: AppColors.surfacePanel,
      elevation: 0,
      offset: const Offset(-4, 34),
      padding: EdgeInsets.zero,
      splashRadius: 1,
      tooltip: '',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        PopupMenuItem<_HeaderMenuAction>(
          value: _HeaderMenuAction.edit,
          height: 38,
          child: Text(
            context.l10n.edit,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          Icons.more_horiz_rounded,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    );
  }
}

enum _HeaderMenuAction { edit }

class _MyListTabs extends StatelessWidget {
  const _MyListTabs({required this.selectedTab, required this.onSelected});

  final MyListTab selectedTab;
  final ValueChanged<MyListTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: 28,
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 0,
            child: _TabLabel(
              text: l10n.myListCollectionTab,
              active: selectedTab == MyListTab.collection,
              onTap: () => onSelected(MyListTab.collection),
            ),
          ),
          Positioned(
            left: 188,
            top: 0,
            child: _TabLabel(
              text: l10n.myListPlayTab,
              active: selectedTab == MyListTab.play,
              onTap: () => onSelected(MyListTab.play),
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
          Positioned(
            left: selectedTab == MyListTab.collection ? 16 : 188,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.primary,
              child: SizedBox(
                width: selectedTab == MyListTab.collection ? 63 : 58,
                height: 2,
              ),
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
        height: 28,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: active ? AppColors.textPrimary : AppColors.textDisabled,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.18,
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
                  const Icon(
                    Icons.delete_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.myListDelete,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
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
      height: 101,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (choosing) ...[
            SizedBox(
              width: 32,
              height: 101,
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
          const SizedBox(width: 12),
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
    final progressWidth = 74 * progress;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: Stack(
        children: [
          _buildCoverImage(assetPath),
          Positioned(
            left: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.primary,
              child: SizedBox(width: progressWidth, height: 2),
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
        width: 74,
        height: 101,
        filterQuality: FilterQuality.medium,
      );
    }

    // 本地 asset
    return Image.asset(
      assetPath,
      width: 74,
      height: 101,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 74,
          height: 101,
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
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            limitTextLines(item.introduction, 2),
            maxLines: 2,
            overflow: TextOverflow.clip,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const Spacer(),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
              children: [
                TextSpan(
                  text: 'EP.${item.currentEpisode}',
                  style: const TextStyle(color: AppColors.primary),
                ),
                TextSpan(
                  text: ' / ${item.episodeCount}',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
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
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
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
    final contentHeight = isIos ? 84.0 : 64.0;

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
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.42),
                    size: 18,
                  ),
                  label: Text('${context.l10n.myListDelete} ($count)'),
                  style: TextButton.styleFrom(
                    foregroundColor: enabled
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.42),
                    disabledForegroundColor: AppColors.textPrimary.withValues(
                      alpha: 0.42,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 21 / 14,
          ),
        ),
      ),
    );
  }
}
