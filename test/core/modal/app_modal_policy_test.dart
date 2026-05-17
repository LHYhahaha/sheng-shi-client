import 'package:drama_client/core/modal/app_modal_dismiss.dart';
import 'package:drama_client/core/modal/app_modal_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard allows barrier and back', () {
    const policy = AppModalDismissPolicy.standard;
    expect(appModalBarrierDismissible(policy), isTrue);
    expect(appModalBackButtonAllowed(policy), isTrue);
  });

  test('blocking disallows barrier but allows back', () {
    const policy = AppModalDismissPolicy.blocking;
    expect(appModalBarrierDismissible(policy), isFalse);
    expect(appModalBackButtonAllowed(policy), isTrue);
  });

  test('nonDismissible and critical disallow barrier and back', () {
    for (final policy in [
      AppModalDismissPolicy.nonDismissible,
      AppModalDismissPolicy.critical,
    ]) {
      expect(appModalBarrierDismissible(policy), isFalse);
      expect(appModalBackButtonAllowed(policy), isFalse);
    }
  });
}
