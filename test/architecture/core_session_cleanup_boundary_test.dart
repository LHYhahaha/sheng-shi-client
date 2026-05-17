import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core/auth does not import features', () {
    final coreAuth = Directory('lib/core/auth');
    final offenders = <String>[];

    for (final entity in coreAuth.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains("import '../../features/") ||
          source.contains("import '../features/") ||
          source.contains('package:drama_client/features/')) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty);
  });
}
