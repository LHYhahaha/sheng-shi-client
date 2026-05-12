import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/feature_placeholder_page.dart';
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
                builder: (context, state) => FeaturePlaceholderPage(
                  title: context.l10n.forYouPlaceholderTitle,
                  description: context.l10n.forYouPlaceholderDescription,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.myList,
                name: RouteNames.myList,
                builder: (context, state) => FeaturePlaceholderPage(
                  title: context.l10n.myListPlaceholderTitle,
                  description: context.l10n.myListPlaceholderDescription,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RoutePaths.profile,
                name: RouteNames.profile,
                builder: (context, state) => FeaturePlaceholderPage(
                  title: context.l10n.profilePlaceholderTitle,
                  description: context.l10n.profilePlaceholderDescription,
                ),
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

          return PlayerPage(dramaId: dramaId, episodeId: episodeId);
        },
      ),
      GoRoute(
        path: RoutePaths.store,
        name: RouteNames.store,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.storePlaceholderTitle,
          description: context.l10n.storePlaceholderDescription,
        ),
      ),
      GoRoute(
        path: RoutePaths.wallet,
        name: RouteNames.wallet,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.walletPlaceholderTitle,
          description: context.l10n.walletPlaceholderDescription,
        ),
      ),
      GoRoute(
        path: RoutePaths.membership,
        name: RouteNames.membership,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.membershipPlaceholderTitle,
          description: context.l10n.membershipPlaceholderDescription,
        ),
      ),
      GoRoute(
        path: RoutePaths.language,
        name: RouteNames.language,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.languagePlaceholderTitle,
          description: context.l10n.languagePlaceholderDescription,
        ),
      ),
      GoRoute(
        path: RoutePaths.transactionHistory,
        name: RouteNames.transactionHistory,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.transactionHistoryPlaceholderTitle,
          description: context.l10n.transactionHistoryPlaceholderDescription,
        ),
      ),
      GoRoute(
        path: RoutePaths.consumptionHistory,
        name: RouteNames.consumptionHistory,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.consumptionHistoryPlaceholderTitle,
          description: context.l10n.consumptionHistoryPlaceholderDescription,
        ),
      ),
      GoRoute(
        path: RoutePaths.recordCoins,
        name: RouteNames.recordCoins,
        builder: (context, state) => FeaturePlaceholderPage(
          title: context.l10n.recordCoinsPlaceholderTitle,
          description: context.l10n.recordCoinsPlaceholderDescription,
        ),
      ),
    ],
  );
});
