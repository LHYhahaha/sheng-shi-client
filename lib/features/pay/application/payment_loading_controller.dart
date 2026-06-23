import 'package:flutter_riverpod/flutter_riverpod.dart';

final paymentLoadingControllerProvider =
    NotifierProvider<PaymentLoadingController, bool>(
      PaymentLoadingController.new,
    );

class PaymentLoadingController extends Notifier<bool> {
  var _visibleRequestCount = 0;

  @override
  bool build() => false;

  void show() {
    _visibleRequestCount += 1;
    state = true;
  }

  void hide() {
    if (_visibleRequestCount > 0) {
      _visibleRequestCount -= 1;
    }
    state = _visibleRequestCount > 0;
  }

  void reset() {
    _visibleRequestCount = 0;
    state = false;
  }
}
