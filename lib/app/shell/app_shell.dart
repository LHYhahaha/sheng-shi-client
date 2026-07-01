import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../features/player/application/player_playback_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    final showBottomNavigation = ref.watch(
      appShellBottomNavigationVisibleProvider,
    );

    // 延迟更新当前 Tab 索引，避免在 build 中修改 provider
    Future.microtask(() {
      ref
          .read(appShellCurrentTabIndexProvider.notifier)
          .setIndex(widget.navigationShell.currentIndex);
    });

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: showBottomNavigation
          ? AppBottomNavigation(
              currentIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: (index) {
                _goBranch(index);
              },
            )
          : null,
    );
  }

  void _goBranch(int index) {
    final currentIndex = widget.navigationShell.currentIndex;
    final playbackProvider = playerPlaybackControllerProvider(
      PlayerPlaybackSessionKeys.forYouTab,
    );

    if (currentIndex == AppShellDestinations.forYouIndex &&
        index != AppShellDestinations.forYouIndex) {
      _resumeForYouOnReturn = ref.read(playbackProvider).isPlaying;
      _forYouVisibilityOperation = _forYouVisibilityOperation.then((_) {
        return ref.read(playbackProvider.notifier).pauseForVisibility();
      });
    } else if (currentIndex != AppShellDestinations.forYouIndex &&
        index == AppShellDestinations.forYouIndex) {
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

    // 检测是否重复点击首页 tab，如果是则通知首页滚动到顶部
    if (index == currentIndex && index == AppShellDestinations.homeIndex) {
      ref.read(homeScrollToTopRequestProvider.notifier).requestScrollToTop();
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == currentIndex,
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
}
