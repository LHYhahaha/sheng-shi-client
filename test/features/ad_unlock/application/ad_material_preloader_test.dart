import 'package:drama_client/features/ad_unlock/application/ad_material_preloader.dart';
import 'package:drama_client/features/ad_unlock/domain/ad_unlock_models.dart';
import 'package:drama_client/features/ad_unlock/domain/ad_unlock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reuses locally cached material without downloading it again', () async {
    final repository = _FakeRepository();
    final downloader = _FakeDownloader();
    final preloader = AdMaterialPreloader(
      repository: repository,
      downloader: downloader,
    );

    await preloader.ensureCachedMaterial();
    await preloader.ensureCachedMaterial();

    expect(repository.preloadIds, [null, 1]);
    expect(downloader.downloadedIds, [1]);
    expect(preloader.cachedMaterial?.id, 1);
  });

  test('reports failure without leaving a partial cached material', () async {
    final preloader = AdMaterialPreloader(
      repository: _FailingPreloadRepository(),
      downloader: _FakeDownloader(),
    );

    final prepared = await preloader.tryEnsureCachedMaterial();

    expect(prepared, isFalse);
    expect(preloader.cachedMaterial, isNull);
    expect(preloader.cachedFilePath, isNull);
  });
}

class _FakeRepository implements AdUnlockRepository {
  final List<int?> preloadIds = [];

  @override
  Future<AdMaterial> preloadMaterial({int? materialId}) async {
    preloadIds.add(materialId);
    return const AdMaterial(
      id: 1,
      fileUrl: 'https://example.test/ad.jpg',
      type: AdMaterialType.image,
    );
  }

  @override
  Future<void> confirmSession({
    required String sessionNo,
    required int watchSeconds,
  }) => throw UnimplementedError();
  @override
  Future<AdUnlockSession> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  }) => throw UnimplementedError();
  @override
  Future<AdUnlockStatus> fetchStatus({
    required int dramaId,
    required int episodeNo,
  }) => throw UnimplementedError();
}

class _FakeDownloader implements AdMaterialDownloader {
  final List<int> downloadedIds = [];
  @override
  Future<String> download(AdMaterial material) async {
    downloadedIds.add(material.id);
    return '/cache/${material.id}';
  }
}

class _FailingPreloadRepository implements AdUnlockRepository {
  @override
  Future<AdMaterial> preloadMaterial({int? materialId}) =>
      Future.error(StateError('network failed'));

  @override
  Future<void> confirmSession({
    required String sessionNo,
    required int watchSeconds,
  }) => throw UnimplementedError();
  @override
  Future<AdUnlockSession> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  }) => throw UnimplementedError();
  @override
  Future<AdUnlockStatus> fetchStatus({
    required int dramaId,
    required int episodeNo,
  }) => throw UnimplementedError();
}
