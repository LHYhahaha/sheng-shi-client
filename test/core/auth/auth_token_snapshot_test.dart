import 'package:drama_client/core/auth/auth_token_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snapshot round-trips session metadata', () {
    const snapshot = AuthTokenSnapshot(
      accessToken: 'guest-access',
      refreshToken: 'guest-refresh',
      sessionKind: AuthTokenSessionKind.guest,
      subjectId: 'guest-subject-1',
      guestId: 'guest-99',
    );

    final restored = AuthTokenSnapshot.fromJson(snapshot.toJson());
    expect(restored.sessionKind, AuthTokenSessionKind.guest);
    expect(restored.subjectId, 'guest-subject-1');
    expect(restored.guestId, 'guest-99');
    expect(restored.refreshToken, 'guest-refresh');
  });

  test('authenticated token kind can be stored separately from guest', () {
    const snapshot = AuthTokenSnapshot(
      accessToken: 'user-access',
      sessionKind: AuthTokenSessionKind.authenticated,
      subjectId: 'user-1',
    );

    expect(snapshot.sessionKind, AuthTokenSessionKind.authenticated);
    expect(snapshot.guestId, isNull);
  });
}
