import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/app_primary_button.dart';
import '../../../../shared/widgets/app_segmented_tabs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _tabs = ['Popular', 'New', 'Ranking', 'Original', 'Asian'];

  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'KiligBox',
      trailing: IconButton(
        tooltip: 'Membership',
        onPressed: () => context.go(RoutePaths.membership),
        icon: const Icon(Icons.workspace_premium),
      ),
      children: [
        AppSegmentedTabs(
          tabs: _tabs,
          selectedIndex: _selectedTab,
          onChanged: (index) => setState(() => _selectedTab = index),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Short Drama Client',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Product shell is ready. Home cards and feed data come next.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Open demo player',
          icon: Icons.play_arrow,
          onPressed: () {
            context.go(
              RoutePaths.playerLocation(
                dramaId: 'demo-drama',
                episodeId: 'episode-1',
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppPrimaryButton(
          label: 'Open store',
          icon: Icons.local_mall,
          onPressed: () => context.go(RoutePaths.store),
        ),
      ],
    );
  }
}
