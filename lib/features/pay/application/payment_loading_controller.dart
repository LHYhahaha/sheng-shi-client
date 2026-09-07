import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentLoadingControllerProvider =
    NotifierProvider<PaymentLoadingController, PaymentLoadingState>(
      PaymentLoadingController.new,
    );

enum PaymentLoadingLabel { none, loading, confirmingPayment }

class PaymentLoadingState {
  const PaymentLoadingState({required this.isVisible, required this.label});

  const PaymentLoadingState.hidden()
    : isVisible = false,
      label = PaymentLoadingLabel.confirmingPayment;

  final bool isVisible;
  final PaymentLoadingLabel label;
}

class PaymentLoadingController extends Notifier<PaymentLoadingState> {
  var _visibleRequestCount = 0;
  var _label = PaymentLoadingLabel.confirmingPayment;

  @override
  PaymentLoadingState build() => const PaymentLoadingState.hidden();

  void show({
    PaymentLoadingLabel label = PaymentLoadingLabel.confirmingPayment,
  }) {
    _visibleRequestCount += 1;
    _label = label;
    state = PaymentLoadingState(isVisible: true, label: _label);
  }

  void hide() {
    if (_visibleRequestCount > 0) {
      _visibleRequestCount -= 1;
    }
    state = _visibleRequestCount > 0
        ? PaymentLoadingState(isVisible: true, label: _label)
        : PaymentLoadingState.hidden();
  }

  void reset() {
    _visibleRequestCount = 0;
    _label = PaymentLoadingLabel.confirmingPayment;
    state = const PaymentLoadingState.hidden();
  }
}
