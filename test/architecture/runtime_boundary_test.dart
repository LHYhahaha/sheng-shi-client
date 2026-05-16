import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core/runtime does not import features/', () {
    final runtimeDir = Directory('lib/core/runtime');
    expect(runtimeDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in runtimeDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final source = entity.readAsStringSync();
      if (source.contains("import '../../features/") ||
          source.contains("import '../../../features/") ||
          source.contains("package:drama_client/features/")) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('AppRuntimeConfig does not reference player domain types', () {
    final files = Directory('lib/core/runtime').listSync(recursive: true);
    final forbidden = [
      'PlayerPerformanceMode',
      'PlayerPerformancePolicy',
      'PlayerPreloadConfig',
    ];
    final offenders = <String>[];

    for (final entity in files) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains(token)) {
          offenders.add('${entity.path} mentions $token');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('features/player application may import core/runtime', () {
    final playerAppDir = Directory('lib/features/player/application');
    expect(playerAppDir.existsSync(), isTrue);

    var sawRuntimeImport = false;
    for (final entity in playerAppDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('core/runtime/')) {
        sawRuntimeImport = true;
        break;
      }
    }
    expect(sawRuntimeImport, isTrue);
  });
}
