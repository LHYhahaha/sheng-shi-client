import 'ad_unlock_models.dart';

abstract interface class AdUnlockRepository {
  Future<AdUnlockStatus> fetchStatus({
    required int dramaId,
    required int episodeNo,
  });

  Future<AdMaterial> preloadMaterial({int? materialId});

  Future<AdUnlockSession> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  });

  Future<void> confirmSession({
    required String sessionNo,
    required int watchSeconds,
  });
}
