import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_exit_recommendation_history_repository.dart';
import 'shared_preferences_player_exit_recommendation_history_repository.dart';

final playerExitRecommendationHistoryRepositoryProvider =
    Provider<PlayerExitRecommendationHistoryRepository>((ref) {
      return SharedPreferencesPlayerExitRecommendationHistoryRepository();
    });
