import '../domain/ad_unlock_models.dart';
import '../domain/ad_unlock_repository.dart';
import 'ad_unlock_remote_data_source.dart';

class RemoteAdUnlockRepository implements AdUnlockRepository {
  const RemoteAdUnlockRepository({required AdUnlockRemoteDataSource dataSource})
    : _dataSource = dataSource;

  final AdUnlockRemoteDataSource _dataSource;

  @override
  Future<void> confirmSession({
    required String sessionNo,
    required int watchSeconds,
  }) => _dataSource.confirmSession(
    sessionNo: sessionNo,
    watchSeconds: watchSeconds,
  );

  @override
  Future<AdUnlockSession> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  }) => _dataSource.createSession(
    dramaId: dramaId,
    episodeNo: episodeNo,
    materialId: materialId,
  );

  @override
  Future<AdUnlockStatus> fetchStatus({
    required int dramaId,
    required int episodeNo,
  }) => _dataSource.fetchStatus(dramaId: dramaId, episodeNo: episodeNo);

  @override
  Future<AdMaterial> preloadMaterial({int? materialId}) =>
      _dataSource.preloadMaterial(materialId: materialId);
}
