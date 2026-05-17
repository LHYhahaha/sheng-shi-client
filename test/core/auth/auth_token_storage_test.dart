import 'package:drama_client/core/auth/auth_token_snapshot.dart';
import 'package:drama_client/core/auth/in_memory_auth_token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-memory storage persists snapshot across read/write', () async {
    final storage = InMemoryAuthTokenStorage();
    const snapshot = AuthTokenSnapshot(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: null,
    );

    await storage.write(snapshot);
    final loaded = await storage.read();

    expect(loaded?.accessToken, 'access-1');
    expect(loaded?.refreshToken, 'refresh-1');
  });

  test('clear removes all token fields', () async {
    final storage = InMemoryAuthTokenStorage();
    await storage.write(
      const AuthTokenSnapshot(accessToken: 'a', refreshToken: 'r'),
    );

    await storage.clear();

    expect(await storage.read(), isNull);
  });

  test('snapshot json roundtrip keeps access and refresh separate', () {
    const original = AuthTokenSnapshot(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresAt: null,
    );

    final restored = AuthTokenSnapshot.fromJson(original.toJson());

    expect(restored.accessToken, 'access');
    expect(restored.refreshToken, 'refresh');
  });
}
