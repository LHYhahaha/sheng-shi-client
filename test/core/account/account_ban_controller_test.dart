import 'package:drama_client/core/account/account_ban_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3116 locks the account and preserves the feedback flow state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(accountBanControllerProvider.notifier);

    controller.reportBusinessCode(1001);
    expect(container.read(accountBanControllerProvider).isBanned, isFalse);

    controller.reportBusinessCode(accountBannedBusinessCode);
    controller.openFeedback();
    controller.reportBusinessCode(accountBannedBusinessCode);

    expect(
      container.read(accountBanControllerProvider),
      isA<AccountBanState>()
          .having((state) => state.isBanned, 'isBanned', isTrue)
          .having(
            (state) => state.isViewingFeedback,
            'isViewingFeedback',
            isTrue,
          ),
    );
  });

  test('only a completed verification clears the ban after feedback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(accountBanControllerProvider.notifier);

    controller.reportBusinessCode(accountBannedBusinessCode);
    controller.openFeedback();
    controller.beginRevalidation();

    expect(
      container.read(accountBanControllerProvider),
      isA<AccountBanState>()
          .having((state) => state.isBanned, 'isBanned', isTrue)
          .having(
            (state) => state.isViewingFeedback,
            'isViewingFeedback',
            isFalse,
          )
          .having(
            (state) => state.isRevalidating,
            'isRevalidating',
            isTrue,
          ),
    );

    controller.completeRevalidationAsBanned();
    expect(container.read(accountBanControllerProvider).isBanned, isTrue);

    controller.clearAfterVerification();
    expect(container.read(accountBanControllerProvider).isBanned, isFalse);
  });
}
