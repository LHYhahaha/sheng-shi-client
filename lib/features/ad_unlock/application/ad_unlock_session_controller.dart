import '../../../core/network/api_exception.dart';
import '../domain/ad_unlock_models.dart';
import '../domain/ad_unlock_repository.dart';

enum AdUnlockSessionState {
  idle,
  creating,
  watching,
  confirming,
  confirmRetry,
  confirmed,
  failed,
}

class AdUnlockSessionController {
  AdUnlockSessionController({required AdUnlockRepository repository})
    : _repository = repository;

  final AdUnlockRepository _repository;
  AdUnlockSessionState state = AdUnlockSessionState.idle;
  AdUnlockSession? session;
  int _watchSeconds = 0;
  Object? error;

  bool get hasSessionInvalidError {
    final value = error;
    if (value is! ApiException) return false;
    return value.code == ApiErrorCode.notFound ||
        value.code == ApiErrorCode.unauthorized ||
        value.code == ApiErrorCode.forbidden ||
        value.code == ApiErrorCode.conflict;
  }

  Future<void> createSession({
    required int dramaId,
    required int episodeNo,
    int? materialId,
  }) async {
    state = AdUnlockSessionState.creating;
    error = null;
    try {
      session = await _repository.createSession(
        dramaId: dramaId,
        episodeNo: episodeNo,
        materialId: materialId,
      );
      state = AdUnlockSessionState.watching;
    } catch (exception) {
      error = exception;
      state = AdUnlockSessionState.failed;
    }
  }

  Future<void> confirm({required int watchSeconds}) async {
    _watchSeconds = watchSeconds;
    final activeSession = session;
    if (activeSession == null) return;
    state = AdUnlockSessionState.confirming;
    error = null;
    try {
      await _repository.confirmSession(
        sessionNo: activeSession.sessionNo,
        watchSeconds: _watchSeconds,
      );
      state = AdUnlockSessionState.confirmed;
    } catch (exception) {
      error = exception;
      state = AdUnlockSessionState.confirmRetry;
    }
  }

  Future<void> retryConfirmation() => confirm(watchSeconds: _watchSeconds);
}
