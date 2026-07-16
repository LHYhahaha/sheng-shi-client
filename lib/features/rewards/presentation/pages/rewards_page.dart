import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import 'member_points_page.dart';
import 'rewards_coins_page.dart';

enum RewardTab {
  rewardsCoins,
  memberPoints;

  static RewardTab fromRouteValue(String? value) {
    return value == RoutePaths.memberPointsTab
        ? RewardTab.memberPoints
        : RewardTab.rewardsCoins;
  }
}

/// 奖励中心容器页。
///
/// 两个子页面保持独立，只由这里负责顶部导航与切换。外部入口可通过路由 query 直接
/// 指定初始页面，后续接入 Rewards coins 数据时无需改动容器结构。
class RewardsPage extends StatefulWidget {
  const RewardsPage({this.initialTab = RewardTab.rewardsCoins, super.key});

  final RewardTab initialTab;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late RewardTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0014),
      body: AnimatedContainer(
        key: const Key('rewards_page_background'),
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: _selectedTab == RewardTab.memberPoints
              ? const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF390E4E), Color(0xFF0E0D0F)],
                  stops: [0, 0.33],
                )
              : const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF4E370D), Color(0xFF121418)],
                  stops: [0, 0.33],
                ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _RewardsNavigation(
                selectedTab: _selectedTab,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RoutePaths.profile);
                  }
                },
                onSelected: (tab) => setState(() => _selectedTab = tab),
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab.index,
                  children: [
                    const RewardsCoinsPage(useParentBackground: true),
                    MemberPointsPage(
                      useParentBackground: true,
                      isActive: _selectedTab == RewardTab.memberPoints,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardsNavigation extends StatelessWidget {
  const _RewardsNavigation({
    required this.selectedTab,
    required this.onBack,
    required this.onSelected,
  });

  final RewardTab selectedTab;
  final VoidCallback onBack;
  final ValueChanged<RewardTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.maybeOf(context);

    return SizedBox(
      height: 58,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('rewards_back_button'),
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 30),
              color: Colors.white,
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RewardTabButton(
                  tabKey: 'rewards_coins',
                  label: l10n.rewardsTabRewardCoins,
                  selected: selectedTab == RewardTab.rewardsCoins,
                  selectedGradientColors: const [
                    Color(0xFFC98455),
                    Color(0xFFFFEFC5),
                  ],
                  selectedUnderColor: Color(0XFFF7DFB9),
                  onTap: () => onSelected(RewardTab.rewardsCoins),
                ),
                const SizedBox(width: 34),
                _RewardTabButton(
                  tabKey: 'member_points',
                  label: l10n.memberPointsTitle,
                  selected: selectedTab == RewardTab.memberPoints,
                  selectedGradientColors: const [
                    Color(0xFFAB59D1),
                    Color(0xFFF1D2FF),
                  ],
                  selectedUnderColor: Color(0XFFDFB6F1),
                  onTap: () => onSelected(RewardTab.memberPoints),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTabButton extends StatelessWidget {
  const _RewardTabButton({
    required this.label,
    required this.tabKey,
    required this.selected,
    required this.selectedGradientColors,
    required this.onTap,
    required this.selectedUnderColor,
  });

  final String label;
  final String tabKey;
  final bool selected;
  final List<Color> selectedGradientColors;
  final VoidCallback onTap;
  final Color selectedUnderColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: Key('rewards_tab_$tabKey'),
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                ShaderMask(
                  key: Key('rewards_tab_gradient_$tabKey'),
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: selectedGradientColors,
                  ).createShader(bounds),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF746779),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 7),
              AnimatedContainer(
                key: Key('rewards_tab_indicator_$tabKey'),
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 2,
                decoration: BoxDecoration(
                  color: selected ? selectedUnderColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
