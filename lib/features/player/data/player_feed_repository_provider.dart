import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_feed.dart';
import 'mock_player_feed_repository.dart';
import 'player_content_repository_provider.dart';

final playerFeedRepositoryProvider = Provider<PlayerFeedRepository>((ref) {
  return MockPlayerFeedRepository(
    contentRepository: ref.watch(playerContentRepositoryProvider),
  );
});
