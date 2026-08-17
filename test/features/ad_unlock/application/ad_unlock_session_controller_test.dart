import 'package:drama_client/features/ad_unlock/application/ad_unlock_session_controller.dart';
import 'package:drama_client/features/ad_unlock/domain/ad_unlock_models.dart';
import 'package:drama_client/features/ad_unlock/domain/ad_unlock_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps confirmed session retryable after confirmation failure',
    () async {
      final repository = _FakeRepository()..failConfirmation = true;
      final controller = AdUnlockSessionController(repository: repository);
      await controller.createSession(dramaId: 1, episodeNo: 2, materialId: 9);

      await controller.confirm(watchSeconds: 12);
      expect(controller.state, AdUnlockSessionState.confirmRetry);
      expect(repository.sessionNo, 'ad-session-1');

      repository.failConfirmation = false;
      await controller.retryConfirmation();
      expect(controller.state, AdUnlockSessionState.confirmed);
      expect(repository.confirmedSessionNos, ['ad-session-1', 'ad-session-1']);
    },
  );
}

class _FakeRepository implements AdUnlockRepository {
  bool failConfirmation = false;
  String? sessionNo;
  final List<String> confirmedSessionNos = [];

  @override
  Future<void> confirmSession({
    required String sessionNo,
    required int watchSeconds,
  }) async {
    this.sessionNo = sessionNo;
    confirmedSessionNos.add(sessionNo);
    if (failConfirmation) throw StateError('offline');
  }

  @override
  Future<AdUnlockSession> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  }) async => AdUnlockSession(
    sessionNo: 'ad-session-1',
    material: const AdMaterial(
      id: 9,
      fileUrl: 'https://ad',
      type: AdMaterialType.image,
    ),
    watchSeconds: 12,
    expiresAt: DateTime(2026),
    reused: false,
  );

  @override
  Future<AdUnlockStatus> fetchStatus({
    required int dramaId,
    required int episodeNo,
  }) => throw UnimplementedError();

  @override
  Future<AdMaterial> preloadMaterial({int? materialId}) =>
      throw UnimplementedError();
}
