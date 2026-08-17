import 'package:drama_client/features/ad_unlock/application/ad_effective_watch_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pauses ordinary background time but continues material H5 time', () {
    final clock = _FakeClock();
    final controller = AdEffectiveWatchController(
      requiredSeconds: 10,
      now: clock.call,
    );

    controller.setMaterialVisible(true);
    clock.elapse(const Duration(seconds: 3));
    controller.setAppForeground(false);
    clock.elapse(const Duration(seconds: 5));
    controller.setExternalH5Open(true);
    clock.elapse(const Duration(seconds: 4));

    expect(controller.watchedSeconds, 7);
    expect(controller.isComplete, isFalse);
  });

  test('freezes accumulated duration on reaching required seconds', () {
    final clock = _FakeClock();
    final controller = AdEffectiveWatchController(
      requiredSeconds: 3,
      now: clock.call,
    );

    controller.setMaterialVisible(true);
    clock.elapse(const Duration(seconds: 5));

    expect(controller.watchedSeconds, 3);
    expect(controller.isComplete, isTrue);
  });
}

class _FakeClock {
  DateTime _now = DateTime(2026, 8, 14);

  DateTime call() => _now;

  void elapse(Duration duration) => _now = _now.add(duration);
}
