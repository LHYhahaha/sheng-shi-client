import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote api guard layer does not import features', () {
    final dir = Directory('lib/core/network');
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (!entity.path.contains('remote_api')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('features/') ||
          source.contains("package:drama_client/features")) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('feature providers still default to mock via RemoteApiSwitches', () {
    final dramaProvider = File(
      'lib/features/drama/data/drama_repository_provider.dart',
    ).readAsStringSync();
    expect(dramaProvider, contains('RemoteApiSwitches.fromEnvironment'));
    expect(dramaProvider, contains('MockDramaRepository'));
  });
}
