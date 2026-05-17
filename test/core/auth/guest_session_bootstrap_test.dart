import 'package:drama_client/core/auth/guest_session_bootstrap.dart';
import 'package:drama_client/core/auth/session_cleanup_coordinator.dart';
import 'package:drama_client/core/auth/session_cleanup_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cleanup invokes guest bootstrap after feature hooks', () async {
    final reasons = <SessionCleanupReason>[];
    final container = ProviderContainer(
      overrides: [
        guestSessionBootstrapProvider.overrideWithValue(
          _RecordingGuestBootstrap(reasons),
        ),
      ],
    );
    addTearDown(container.dispose);

    final coordinator = container.read(sessionCleanupCoordinatorProvider);
    await coordinator.cleanup(SessionCleanupReason.logout);

    expect(reasons, [SessionCleanupReason.logout]);
  });
}

class _RecordingGuestBootstrap extends GuestSessionBootstrap {
  _RecordingGuestBootstrap(this.reasons);

  final List<SessionCleanupReason> reasons;

  @override
  Future<void> bootstrapAfterSessionCleanup(SessionCleanupReason reason) async {
    reasons.add(reason);
  }
}
