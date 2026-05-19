import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drama')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Short Drama Client',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Foundation is ready. Feed, drama detail, and playback come next.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              context.go(
                RoutePaths.playerLocation(
                  dramaId: 'demo-drama',
                  episodeId: 'episode-1',
                ),
              );
            },
            child: const Text('Open demo player'),
          ),
        ],
      ),
    );
  }
}
