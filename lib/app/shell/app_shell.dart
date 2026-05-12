import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../shared/widgets/navigation/app_bottom_navigation.dart';
import 'app_shell_chrome.dart';

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
              onDestinationSelected: _goBranch,
            )
          : null,
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class AppShellDestinations {
  const AppShellDestinations._();

  static const paths = [
    RoutePaths.home,
    RoutePaths.forYou,
    RoutePaths.myList,
    RoutePaths.profile,
  ];
}
