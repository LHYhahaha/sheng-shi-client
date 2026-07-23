import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
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

  @override
  void initState() {
    super.initState();
    _lastNavigationIndex = widget.navigationShell.currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _requestPopupForIndex(widget.navigationShell.currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationIndex = widget.navigationShell.currentIndex;
    if (_lastNavigationIndex != navigationIndex) {
      _syncForYouVisibilityForNavigationChange(
        from: _lastNavigationIndex,
        to: navigationIndex,
      );
      _lastNavigationIndex = navigationIndex;
    }
    final showBottomNavigation = ref.watch(
      appShellBottomNavigationVisibleProvider,
    );

    // 单剧播放器覆盖 Shell 时会隐藏底部导航。若应用在播放器页停留超过
    // 30 分钟，PopupEntryController 只会重置请求周期而不会请求；返回到可展示
    // 弹窗的首页/For You 后，再由这里按当前 tab 发起检查与请求。
    ref.listen<bool>(appShellBottomNavigationVisibleProvider, (previous, next) {
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
