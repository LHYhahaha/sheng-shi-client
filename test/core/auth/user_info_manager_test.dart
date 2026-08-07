import 'package:drama_client/core/auth/user_info_manager.dart';
import 'package:drama_client/core/auth/user_info_store.dart';
import 'package:drama_client/features/auth/domain/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps userId separate from the display-only showId', () {
    const snapshot = UserInfoSnapshot(
      userId: '2072231756014030848',
      showId: '293944466',
      nickname: 'Nova user',
    );

    final session = UserInfoManager.buildSessionFromUserInfo(
      snapshot,
      provider: AuthProviderType.google,
    );

    expect(session.user?.userId, '2072231756014030848');
    expect(session.user?.showId, '293944466');
  });
}
