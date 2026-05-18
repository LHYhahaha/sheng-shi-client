import 'package:drama_client/features/auth/application/account_cancellation_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canSubmit requires risk acceptance and finished countdown', () {
    final container = ProviderContainer(
      overrides: [accountCancellationCountdownProvider.overrideWithValue(0)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      accountCancellationControllerProvider.notifier,
    );

    expect(
      container.read(accountCancellationControllerProvider).canSubmit,
      isFalse,
    );

    notifier.setAcceptedRisk(true);
    expect(
      container.read(accountCancellationControllerProvider).canSubmit,
      isTrue,
    );

    notifier.setSubmitting(true);
    expect(
      container.read(accountCancellationControllerProvider).canSubmit,
      isFalse,
    );
  });
}
