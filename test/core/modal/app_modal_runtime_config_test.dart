import 'package:drama_client/core/modal/app_modal_runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults keep global modal enabled with conservative queue', () {
    const config = AppModalRuntimeConfig.defaults;
    expect(config.enableGlobalModalSystem, isTrue);
    expect(config.enableModalDiagnostics, isFalse);
    expect(config.maxQueueLength, 5);
    expect(config.allowPreemption, isFalse);
  });
}
