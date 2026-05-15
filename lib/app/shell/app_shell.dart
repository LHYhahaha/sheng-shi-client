import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../features/player/application/player_playback_controller.dart';
import '../../shared/widgets/navigation/app_bottom_navigation.dart';
import 'app_shell_chrome.dart';

/// 主导航 shell。
///
/// Shell 只管理 tab 容器和底部导航显示，不拥有播放器 session。离开 For You tab 时
/// 通过播放器 controller 调 pauseForVisibility，让播放链路自己释放预热和窗口资源。
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBottomNavigation = ref.watch(
      appShellBottomNavigationVisibleProvider,
    );

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: showBottomNavigation
          ? AppBottomNavigation(
              currentIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                _goBranch(ref, index);
              },
            )
          : null,
    );
  }

  void _goBranch(WidgetRef ref, int index) {
    if (navigationShell.currentIndex == AppShellDestinations.forYouIndex &&
        index != AppShellDestinations.forYouIndex) {
      // For You tab 在 indexedStack 中仍然挂载；切走时必须显式暂停可见性。
      // 不能等 dispose，因为 tab 页面不会销毁，继续播放会造成后台出声和网络占用。
      unawaited(
        ref
            .read(
              playerPlaybackControllerProvider(
                PlayerPlaybackSessionKeys.forYouTab,
              ).notifier,
            )
            .pauseForVisibility(),
      );
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class AppShellDestinations {
  const AppShellDestinations._();

  static const forYouIndex = 1;

  static const paths = [
    RoutePaths.home,
    RoutePaths.forYou,
    RoutePaths.myList,
    RoutePaths.profile,
  ];
}
