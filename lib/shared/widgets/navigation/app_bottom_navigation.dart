import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/app_colors.dart';

/// 应用底部主导航。
///
/// 只服务可见的 shell tab。播放器全屏、My List 编辑等场景应通过 shell chrome provider
/// 隐藏它，不要在单个页面里复制导航栏。
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  static const _contentWidth = 288.0;
  static const _itemWidth = 64.0;
  static const _iconSize = 24.0;

  static const _items = [
    _BottomNavigationItem(
      destinationIndex: 0,
      label: _BottomNavigationLabel.home,
      selectedAssetPath: 'assets/navigation/home_selected.png',
      unselectedAssetPath: 'assets/navigation/home_unselected.png',
      fallbackIcon: Icons.home_rounded,
    ),
    _BottomNavigationItem(
      destinationIndex: 1,
      label: _BottomNavigationLabel.forYou,
      selectedAssetPath: 'assets/navigation/for_you_selected.png',
      unselectedAssetPath: 'assets/navigation/for_you_unselected.png',
      fallbackIcon: Icons.play_circle_fill_rounded,
    ),
    // 会员 Tab 暂不在当前版本展示；保留对应 shell branch，避免影响现有路由。
    _BottomNavigationItem(
      destinationIndex: 3,
      label: _BottomNavigationLabel.myList,
      selectedAssetPath: 'assets/navigation/my_list_selected.png',
      unselectedAssetPath: 'assets/navigation/my_list_unselected.png',
      fallbackIcon: Icons.explore_rounded,
    ),
    _BottomNavigationItem(
      destinationIndex: 4,
      label: _BottomNavigationLabel.profile,
      selectedAssetPath: 'assets/navigation/profile_selected.png',
      unselectedAssetPath: 'assets/navigation/profile_unselected.png',
      fallbackIcon: Icons.person_rounded,
    ),
  ];

  /// 当前选中 tab 索引。
  final int currentIndex;

  /// tab 点击回调。
  ///
  /// Shell 会在这里处理 For You pauseForVisibility，再交给 navigationShell 切换。
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final platform = Theme.of(context).platform;
    final isIos = platform == TargetPlatform.iOS;
    final contentHeight = isIos ? 84.0 : 64.0;
    final bottomInset = isIos ? 0.0 : mediaQuery.viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0014),
        border: const Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
      ),
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
                child: SizedBox(
                  width: _contentWidth,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final item in _items)
                        _AppBottomNavigationItem(
                          key: ValueKey('bottom_nav_${item.label.name}'),
                          label: item.label.resolve(context.l10n),
                          selectedAssetPath: item.selectedAssetPath,
                          unselectedAssetPath: item.unselectedAssetPath,
                          fallbackIcon: item.fallbackIcon,
                          selected: item.destinationIndex == currentIndex,
                          height: contentHeight,
                          onTap: () =>
                              onDestinationSelected(item.destinationIndex),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (isIos)
              const Positioned(left: 120, bottom: 9, child: _HomeIndicator()),
          ],
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const SizedBox(width: 135, height: 5),
    );
  }
}

class _AppBottomNavigationItem extends StatelessWidget {
  const _AppBottomNavigationItem({
    required this.label,
    required this.selectedAssetPath,
    required this.unselectedAssetPath,
    required this.fallbackIcon,
    required this.selected,
    required this.height,
    required this.onTap,
    super.key,
  });

  final String label;
  final String selectedAssetPath;
  final String unselectedAssetPath;
  final IconData fallbackIcon;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.navigationInactive;

    return SizedBox(
      width: AppBottomNavigation._itemWidth,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 9,
              child: SizedBox.square(
                dimension: AppBottomNavigation._iconSize,
                child: Image.asset(
                  selected ? selectedAssetPath : unselectedAssetPath,
                  width: AppBottomNavigation._iconSize,
                  height: AppBottomNavigation._iconSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      fallbackIcon,
                      size: AppBottomNavigation._iconSize,
                      color: color,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 36,
              left: 0,
              right: 0,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigationItem {
  const _BottomNavigationItem({
    required this.destinationIndex,
    required this.label,
    required this.selectedAssetPath,
    required this.unselectedAssetPath,
    required this.fallbackIcon,
  });

  final int destinationIndex;
  final _BottomNavigationLabel label;
  final String selectedAssetPath;
  final String unselectedAssetPath;
  final IconData fallbackIcon;
}

enum _BottomNavigationLabel {
  home,
  forYou,
  myList,
  game,
  member,
  profile;

  String resolve(AppLocalizations l10n) {
    return switch (this) {
      _BottomNavigationLabel.home => l10n.navHome,
      _BottomNavigationLabel.forYou => l10n.navForYou,
      _BottomNavigationLabel.myList => l10n.navMyList,
      _BottomNavigationLabel.game => l10n.navGame,
      _BottomNavigationLabel.member => l10n.navMember,
      _BottomNavigationLabel.profile => l10n.navProfile,
    };
  }
}
