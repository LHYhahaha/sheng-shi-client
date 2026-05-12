import 'package:flutter/material.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  static const _contentWidth = 354.0;
  static const _itemWidth = 72.0;
  static const _iconSize = 24.0;

  static const _items = [
    _BottomNavigationItem(Icons.home_rounded, 'Home'),
    _BottomNavigationItem(Icons.play_circle_fill_rounded, 'For you'),
    _BottomNavigationItem(Icons.explore_rounded, 'My list'),
    _BottomNavigationItem(Icons.person_rounded, 'Profile'),
  ];

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final platform = Theme.of(context).platform;
    final isIos = platform == TargetPlatform.iOS;
    final contentHeight = isIos ? 84.0 : 64.0;
    final bottomInset = isIos ? 0.0 : mediaQuery.viewPadding.bottom;

    return ColoredBox(
      color: const Color(0xFF4D4D4D),
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
                      for (final item in _items.indexed)
                        _AppBottomNavigationItem(
                          icon: item.$2.icon,
                          label: item.$2.label,
                          selected: item.$1 == currentIndex,
                          height: contentHeight,
                          onTap: () => onDestinationSelected(item.$1),
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
    required this.icon,
    required this.label,
    required this.selected,
    required this.height,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFF807F7F);

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
                child: Icon(
                  icon,
                  size: AppBottomNavigation._iconSize,
                  color: color,
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
  const _BottomNavigationItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
