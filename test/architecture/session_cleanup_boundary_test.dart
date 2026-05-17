import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session cleanup hooks register in bootstrap only', () {
    final bootstrap = File(
      'lib/bootstrap/feature_session_cleanup.dart',
    ).readAsStringSync();
    expect(bootstrap, contains('registerFeatureHooks'));
    expect(bootstrap, contains('dismissAllBlockingBusinessModals'));
    expect(bootstrap, contains('resetForSessionCleanup'));
    expect(bootstrap, contains('runPlayerSessionCleanupWith'));
  });

  test('session cleanup coordinator does not import features', () {
    final source = File(
      'lib/core/auth/session_cleanup_coordinator.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('features/')));
    expect(source, isNot(contains('package:drama_client/features')));
  });
}
