import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/runtime/startup_loading_timing.dart';

void main() {
  test('ends only the active startup loading measurement', () {
    final timing = StartupLoadingTiming();

    expect(timing.end(), isNull);

    timing.start();

    expect(timing.mark('auth start'), isNotNull);
    expect(timing.end(), isNotNull);
    expect(timing.end(), isNull);
  });

  test('notifies waiters when startup loading ends', () async {
    final timing = StartupLoadingTiming();
    timing.start();

    var completed = false;
    final completion = timing.waitForEnd().then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    timing.end();
    await completion;
    expect(completed, isTrue);
  });
}
