import 'package:drama_client/bootstrap/feature_session_cleanup.dart';
import 'package:drama_client/core/auth/session_cleanup_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logout cleanup does not start a second device login', () {
    expect(
      shouldRestoreGuestSessionAfterCleanup(SessionCleanupReason.logout),
      isFalse,
    );
  });

  test('authentication failures still restore a guest session', () {
    expect(
      shouldRestoreGuestSessionAfterCleanup(SessionCleanupReason.refreshFailed),
      isTrue,
    );
    expect(
      shouldRestoreGuestSessionAfterCleanup(
        SessionCleanupReason.sessionExpired,
      ),
      isTrue,
    );
  });
}
