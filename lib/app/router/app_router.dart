import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
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
        path: RoutePaths.player,
        name: RouteNames.player,
        builder: (context, state) {
          final dramaId = state.pathParameters['dramaId']!;
          final episodeId = state.pathParameters['episodeId']!;

          return PlayerPage(dramaId: dramaId, episodeId: episodeId);
        },
      ),
    ],
  );
});
