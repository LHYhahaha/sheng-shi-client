import 'dart:async';

import 'package:drama_client/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/analytics/analytics_page_tracker.dart';
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

  String get analyticsPageName => switch (this) {
    RewardTab.rewardsCoins => AnalyticsPageNames.rewardCoin,
    RewardTab.memberPoints => AnalyticsPageNames.memberPoints,
  };
}

/// 奖励中心容器页。
///
/// 两个子页面保持独立，只由这里负责顶部导航与切换。外部入口可通过路由 query 直接
/// 指定初始页面，后续接入 Rewards coins 数据时无需改动容器结构。
class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({this.initialTab = RewardTab.rewardsCoins, super.key});

  final RewardTab initialTab;

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  late RewardTab _selectedTab;
  late AnalyticsPageTracker _pageTracker;
  bool _hasStartedAnalyticsSession = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    // dispose 阶段不能再通过 ref 获取 provider，提前保留实例以结束当前 Tab 会话。
    _pageTracker = ref.read(analyticsPageTrackerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _hasStartedAnalyticsSession = true;
      unawaited(_pageTracker.push(_selectedTab.analyticsPageName));
    });
  }

  @override
  void didUpdateWidget(RewardsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _selectTab(widget.initialTab);
    }
  }

  @override
  void dispose() {
    // RewardsPage 是一个路由容器，两个 Tab 都是同一个 route 内的独立页面会话。
    // 路由退出时结束当前可见 Tab；tracker 会按导航栈恢复返回页的 page_view。
    if (_hasStartedAnalyticsSession) {
      unawaited(_pageTracker.pop(_selectedTab.analyticsPageName));
    }
    super.dispose();
  }

  void _selectTab(RewardTab tab) {
    if (tab == _selectedTab) {
      return;
    }
    setState(() => _selectedTab = tab);
    if (_hasStartedAnalyticsSession) {
      // replace 会先结束旧 Tab 的 page_leave，再开始新 Tab 的 page_view。
      unawaited(_pageTracker.replace(tab.analyticsPageName));
    }
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
                onSelected: _selectTab,
              ),
              Expanded(
                child: IndexedStack(
                  index: _selectedTab.index,
                  children: [
                    RewardsCoinsPage(
                      useParentBackground: true,
                      isActive: _selectedTab == RewardTab.rewardsCoins,
                    ),
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
              const SizedBox(height: 2),
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
