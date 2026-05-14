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
import '../../features/store/presentation/pages/store_page.dart';
import '../../features/wallet/domain/wallet_record.dart';
import '../../features/wallet/presentation/pages/wallet_history_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import 'route_names.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
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
