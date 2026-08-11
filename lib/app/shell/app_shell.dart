import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../core/account/account_ban_controller.dart';
import '../../core/analytics/analytics_page_tracker.dart';
import '../../core/analytics/analytics_entry_source.dart';
import '../../features/bottom_tab_config/application/bottom_tab_config_controller.dart';
import '../../features/player/application/player_playback_controller.dart';
import '../../features/popup/application/popup_entry_controller.dart';
import '../../features/popup/domain/popup.dart';
import '../../shared/widgets/navigation/app_bottom_navigation.dart';
import 'app_shell_chrome.dart';

/// 当前 Shell Tab 索引的 notifier。
class _CurrentTabIndexNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void setIndex(int index) {
    state = index;
  }
}

/// 当前 Shell Tab 索引的 provider。
final appShellCurrentTabIndexProvider =
    NotifierProvider<_CurrentTabIndexNotifier, int>(
      _CurrentTabIndexNotifier.new,
    );

/// 首页滚动到顶部的请求计数 notifier。
class _HomeScrollToTopNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void requestScrollToTop() {
    state++;
  }
}

/// 首页滚动到顶部的通知 provider。
///
/// 当重复点击首页 tab 时，这个 provider 会增加计数，
/// HomePage 会监听这个变化并执行滚动到顶部的操作。
final homeScrollToTopRequestProvider =
    NotifierProvider<_HomeScrollToTopNotifier, int>(
      _HomeScrollToTopNotifier.new,
    );

/// 会员 tab 刷新请求计数 notifier。
class _MemberTabRefreshRequestNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void requestRefresh() {
    state++;
  }
}

/// 会员 tab 刷新通知 provider。
///
/// 当重复点击会员 tab 时，这个 provider 会增加计数，MemberTabPage 会静默刷新商品价钱。
final memberTabRefreshRequestProvider =
    NotifierProvider<_MemberTabRefreshRequestNotifier, int>(
      _MemberTabRefreshRequestNotifier.new,
    );

/// 主导航 shell。
///
/// Shell 只管理 tab 容器和底部导航显示，不拥有播放器 session。离开 For You tab 时
/// 通过播放器 controller 调 pauseForVisibility，让播放链路自己释放预热和窗口资源。
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  /// go_router 提供的 StatefulShell。
  ///
  /// 它负责保留四个主 tab 的页面栈；Shell 只在切 tab 时补充播放器可见性处理。
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _resumeForYouOnReturn = false;
  Future<void> _forYouVisibilityOperation = Future<void>.value();
  late int _lastNavigationIndex;
  bool _shellReadyEffectsStarted = false;

  @override
  void initState() {
    super.initState();
    _lastNavigationIndex = widget.navigationShell.currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    final bottomTabConfig = ref.watch(bottomTabConfigControllerProvider);
    // 冷启动先完成动态 Tab 配置判定。无论接口成功还是失败，hasLoaded 均会置为 true；
    // 失败时随后展示完整默认导航，避免默认首页先绘制再被 H5 替换。
    if (!bottomTabConfig.hasLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0014),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final navigationIndex = widget.navigationShell.currentIndex;
    if (!_shellReadyEffectsStarted) {
      _shellReadyEffectsStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _requestPopupForIndex(widget.navigationShell.currentIndex);
        _trackPageForIndex(widget.navigationShell.currentIndex);
      });
    }
    if (_lastNavigationIndex != navigationIndex) {
      final previousIndex = _lastNavigationIndex;
      final previousPlacement = AppShellDestinations.popupPlacementForIndex(
        previousIndex,
      );
      if (previousPlacement != null) {
        ref
            .read(popupEntryControllerProvider.notifier)
            .cancelPlacementFlow(previousPlacement);
      }
      _syncForYouVisibilityForNavigationChange(
        from: _lastNavigationIndex,
        to: navigationIndex,
      );
      _lastNavigationIndex = navigationIndex;
      _trackPageForIndex(navigationIndex);
    }
    final showBottomNavigation = ref.watch(
      appShellBottomNavigationVisibleProvider,
    );

    // 单剧播放器覆盖 Shell 时，需要立即取消首页/For You 的弹框 flow。
    // 返回时仍交给 controller 的「当前前台周期是否已请求」保护：普通返回不会
    // 重复弹窗；若后台停留超过 30 分钟已重置请求周期，则回到对应 Tab 时会重拉。
    ref.listen<bool>(appShellBottomNavigationVisibleProvider, (previous, next) {
      if (previous == true && !next) {
        final placement = AppShellDestinations.popupPlacementForIndex(
          widget.navigationShell.currentIndex,
        );
        if (placement != null) {
          ref
              .read(popupEntryControllerProvider.notifier)
              .cancelPlacementFlow(placement);
        }
        return;
      }
      if (previous == false && next) {
        _requestPopupForIndex(widget.navigationShell.currentIndex);
      }
    });

    // 延迟更新当前 Tab 索引，避免在 build 中修改 provider
    Future.microtask(() {
      ref
          .read(appShellCurrentTabIndexProvider.notifier)
          .setIndex(navigationIndex);
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: showBottomNavigation
          ? AppBottomNavigation(
              currentIndex: navigationIndex,
              onDestinationSelected: (index) {
                _goBranch(index);
              },
            )
          : null,
    );
  }

  void _goBranch(int index) {
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    final currentIndex = widget.navigationShell.currentIndex;
    _syncForYouVisibilityForNavigationChange(from: currentIndex, to: index);
    _lastNavigationIndex = index;

    // 检测是否重复点击首页 tab，如果是则通知首页滚动到顶部
    if (index == currentIndex && index == AppShellDestinations.homeIndex) {
      ref.read(homeScrollToTopRequestProvider.notifier).requestScrollToTop();
    }
    if (index == currentIndex && index == AppShellDestinations.memberIndex) {
      ref.read(memberTabRefreshRequestProvider.notifier).requestRefresh();
    }

    if (index != currentIndex) {
      final previousPlacement = AppShellDestinations.popupPlacementForIndex(
        currentIndex,
      );
      if (previousPlacement != null) {
        ref
            .read(popupEntryControllerProvider.notifier)
            .cancelPlacementFlow(previousPlacement);
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == currentIndex,
    );
    _requestPopupForIndex(index);
    _trackPageForIndex(index);
  }

  /// Handles both bottom-navigation taps and router-driven branch changes.
  ///
  /// `context.go('/home')` does not call [_goBranch], while the For You branch
  /// stays alive in StatefulShell's indexed stack. Watching the shell index is
  /// essential so that route-driven exits cannot leave its audio playing.
  void _syncForYouVisibilityForNavigationChange({
    required int from,
    required int to,
  }) {
    if (from == to) {
      return;
    }
    final playbackProvider = playerPlaybackControllerProvider(
      PlayerPlaybackSessionKeys.forYouTab,
    );
    if (from == AppShellDestinations.forYouIndex &&
        to != AppShellDestinations.forYouIndex) {
      final playback = ref.read(playbackProvider);
      _resumeForYouOnReturn =
          playback.currentSource != null || playback.isOpening;
      _forYouVisibilityOperation = _forYouVisibilityOperation.then((_) {
        return ref.read(playbackProvider.notifier).pauseForVisibility();
      });
      return;
    }
    if (from != AppShellDestinations.forYouIndex &&
        to == AppShellDestinations.forYouIndex) {
      final shouldResume = _resumeForYouOnReturn;
      _resumeForYouOnReturn = false;
      if (shouldResume) {
        _forYouVisibilityOperation = _forYouVisibilityOperation.then((_) {
          return ref
              .read(playbackProvider.notifier)
              .resumeAfterVisibilityPause();
        });
      }
    }
  }

  void _requestPopupForIndex(int index) {
    if (ref.read(accountBanControllerProvider).isBanned) {
      return;
    }
    final placement = AppShellDestinations.popupPlacementForIndex(index);
    if (placement == null) {
      return;
    }
    unawaited(
      ref
          .read(popupEntryControllerProvider.notifier)
          .requestForPlacement(placement),
    );
  }

  void _trackPageForIndex(int index) {
    final pageName = switch (index) {
      AppShellDestinations.homeIndex => AnalyticsPageNames.home,
      AppShellDestinations.forYouIndex => AnalyticsPageNames.recommend,
      AppShellDestinations.memberIndex => AnalyticsPageNames.vipTab,
      AppShellDestinations.myListIndex => AnalyticsPageNames.favorite,
      AppShellDestinations.profileIndex => AnalyticsPageNames.my,
      _ => null,
    };
    if (pageName != null) {
      unawaited(
        ref
            .read(analyticsPageTrackerProvider)
            .replace(
              pageName,
              forcePageView: ref
                  .read(analyticsEntrySourceProvider.notifier)
                  .hasPending,
            ),
      );
    }
  }
}

class AppShellDestinations {
  const AppShellDestinations._();

  static const homeIndex = 0;
  static const forYouIndex = 1;
  static const memberIndex = 2;
  static const myListIndex = 3;
  static const profileIndex = 4;

  static const paths = [
    RoutePaths.home,
    RoutePaths.forYou,
    RoutePaths.member,
    RoutePaths.myList,
    RoutePaths.profile,
  ];

  static PopupPlacementCode? popupPlacementForIndex(int index) {
    return switch (index) {
      homeIndex => PopupPlacementCode.homeEnter,
      forYouIndex => PopupPlacementCode.recommendTabEnter,
      _ => null,
    };
  }
}
