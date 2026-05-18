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

  test('countdown starts only after accepting deletion risk', () async {
    final container = ProviderContainer(
      overrides: [accountCancellationCountdownProvider.overrideWithValue(2)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      accountCancellationControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final notifier = container.read(
      accountCancellationControllerProvider.notifier,
    );

    expect(
      container.read(accountCancellationControllerProvider).remainingSeconds,
      2,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      container.read(accountCancellationControllerProvider).remainingSeconds,
      2,
    );

    notifier.setAcceptedRisk(true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(
      container.read(accountCancellationControllerProvider).remainingSeconds,
      1,
    );

    notifier.setAcceptedRisk(false);
    expect(
      container.read(accountCancellationControllerProvider).remainingSeconds,
      2,
    );
    expect(
      container.read(accountCancellationControllerProvider).canSubmit,
      isFalse,
    );
  });
}
