import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/membership/presentation/pages/membership_page.dart';
import '../../features/my_list/presentation/pages/my_list_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/profile/presentation/pages/language_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/settings_page.dart';
import '../../features/store/presentation/pages/store_page.dart';
import '../../features/wallet/domain/wallet_record.dart';
import '../../features/wallet/presentation/pages/wallet_history_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// 应用路由表。
///
/// 页面跳转统一通过 RoutePaths/RouteNames，避免散落字符串。播放器路由尤其敏感：
/// For You 在 shell 内保留底部导航，单剧播放器在 shell 外全屏并由 PlayerPage 管理
/// hide/show bottom navigation。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
      // 底部四个主 tab 使用 indexedStack 保持页面状态。
      //
      // For You 播放器因此不会因为切到 Home/Profile 就被销毁；离开 tab 时的暂停
      // 由 AppShell 统一触发，避免路由层和播放器层互相直接依赖。
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.home,
                name: RouteNames.home,
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.forYou,
                name: RouteNames.forYou,
                builder: (context, state) => const PlayerPage.forYou(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.myList,
                name: RouteNames.myList,
                builder: (context, state) => const MyListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.player,
        name: RouteNames.player,
        builder: (context, state) {
          final dramaId = state.pathParameters['dramaId']!;
          final episodeId = state.pathParameters['episodeId']!;
          final userActionAtMs = int.tryParse(
            state.uri.queryParameters['userActionAtMs'] ?? '',
          );

          // 单剧播放器是 shell 外 route，进入时隐藏/显示底部导航由 PlayerPage 的
          // hideShellNavigation 和 dispose 处理。这里仅传递触发来源和点击时间，
          // 用于 playback timing trace 关联“用户点击 -> 首帧”。
          return PlayerPage(
            dramaId: dramaId,
            episodeId: episodeId,
            initialPlaybackTrigger: state.uri.queryParameters['trigger'],
            initialUserActionAt: userActionAtMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(userActionAtMs),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.store,
        name: RouteNames.store,
        builder: (context, state) => const StorePage(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: RoutePaths.account,
        name: RouteNames.account,
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        builder: (context, state) => const WalletPage(),
      ),
      GoRoute(
        path: RoutePaths.membership,
        name: RouteNames.membership,
        builder: (context, state) => const MembershipPage(),
      ),
      GoRoute(
        path: RoutePaths.language,
        name: RouteNames.language,
        builder: (context, state) => const LanguagePage(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: RoutePaths.transactionHistory,
        name: RouteNames.transactionHistory,
        builder: (context, state) =>
            const WalletHistoryPage(type: WalletRecordType.transaction),
      ),
      GoRoute(
        path: RoutePaths.consumptionHistory,
        name: RouteNames.consumptionHistory,
        builder: (context, state) =>
            const WalletHistoryPage(type: WalletRecordType.consumption),
      ),
      GoRoute(
        path: RoutePaths.recordCoins,
        name: RouteNames.recordCoins,
        builder: (context, state) =>
            const WalletHistoryPage(type: WalletRecordType.coins),
      ),
    ],
  );
});
