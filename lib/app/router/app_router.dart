import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../shared/widgets/feature_placeholder_page.dart';
import 'route_names.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        name: RouteNames.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: RoutePaths.forYou,
        name: RouteNames.forYou,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'For you',
          description: 'Short drama playback feed comes in M3.',
        ),
      ),
      GoRoute(
        path: RoutePaths.player,
        name: RouteNames.player,
        builder: (context, state) {
          final dramaId = state.pathParameters['dramaId']!;
          final episodeId = state.pathParameters['episodeId']!;

          return PlayerPage(dramaId: dramaId, episodeId: episodeId);
        },
      ),
      GoRoute(
        path: RoutePaths.myList,
        name: RouteNames.myList,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'My list',
          description: 'Collection list and play list come in M4.',
        ),
      ),
      GoRoute(
        path: RoutePaths.profile,
        name: RouteNames.profile,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Profile',
          description:
              'Guest/login state, wallet, and membership entries come in M4.',
        ),
      ),
      GoRoute(
        path: RoutePaths.store,
        name: RouteNames.store,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Store',
          description: 'Coin and VIP recharge packages come in M5.',
        ),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'My Wallet',
          description: 'Balance and wallet actions come in M5.',
        ),
      ),
      GoRoute(
        path: RoutePaths.membership,
        name: RouteNames.membership,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Membership',
          description: 'VIP plans and benefits come in M5.',
        ),
      ),
      GoRoute(
        path: RoutePaths.language,
        name: RouteNames.language,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Language',
          description:
              'Language settings are deferred until after MVP localization.',
        ),
      ),
      GoRoute(
        path: RoutePaths.transactionHistory,
        name: RouteNames.transactionHistory,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Transaction history',
          description: 'Wallet transaction records come in M5.',
        ),
      ),
      GoRoute(
        path: RoutePaths.consumptionHistory,
        name: RouteNames.consumptionHistory,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Consumption history',
          description:
              'Episode unlock and coin consumption records come in M5.',
        ),
      ),
      GoRoute(
        path: RoutePaths.recordCoins,
        name: RouteNames.recordCoins,
        builder: (context, state) => const FeaturePlaceholderPage(
          title: 'Record Coins',
          description: 'Check-in and reward coins come in M5.',
        ),
      ),
    ],
  );
});
