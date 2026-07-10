abstract interface class PlayerExitRecommendationHistoryRepository {
  Future<bool> hasShown({required String userKey, required String dramaId});

  Future<void> markShown({required String userKey, required String dramaId});
}
