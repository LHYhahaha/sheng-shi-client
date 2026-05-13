import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_content.dart';
import 'mock_player_content_repository.dart';

final playerContentRepositoryProvider = Provider<PlayerContentRepository>((
  ref,
) {
  return const MockPlayerContentRepository();
});
