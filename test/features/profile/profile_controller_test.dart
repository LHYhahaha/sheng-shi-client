import 'package:drama_client/features/profile/application/profile_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides mock profile state outside widgets', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(profileControllerProvider);

    expect(state.isLoggedIn, isFalse);
    expect(state.userId, '15589299');
    expect(
      state.avatarAssetPath,
      'assets/images/profile/profile_avatar_figma.png',
    );
    expect(state.membership.entryEnabled, isTrue);
    expect(state.coins.balance, 2000);
    expect(state.coins.topUpEnabled, isTrue);
    expect(state.language.entryEnabled, isTrue);
  });
}
