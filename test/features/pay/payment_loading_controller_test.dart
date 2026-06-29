import 'package:drama_client/features/pay/application/payment_loading_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payment loading tracks visible label by phase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(paymentLoadingControllerProvider.notifier);

    controller.show(label: PaymentLoadingLabel.loading);
    var state = container.read(paymentLoadingControllerProvider);
    expect(state.isVisible, isTrue);
    expect(state.label, PaymentLoadingLabel.loading);

    controller.hide();
    state = container.read(paymentLoadingControllerProvider);
    expect(state.isVisible, isFalse);

    controller.show();
    state = container.read(paymentLoadingControllerProvider);
    expect(state.isVisible, isTrue);
    expect(state.label, PaymentLoadingLabel.confirmingPayment);
  });
}
