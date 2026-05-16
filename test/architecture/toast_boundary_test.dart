import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('features layer must not import bot_toast directly', () {
    final featuresDir = Directory('lib/features');
    expect(featuresDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in featuresDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains("package:bot_toast/") ||
          source.contains("import 'package:bot_toast")) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('features may import core toast provider', () {
    final playerPage = File(
      'lib/features/player/presentation/pages/player_page.dart',
    );
    final source = playerPage.readAsStringSync();
    expect(source, contains('core/toast/app_toast_provider.dart'));
    expect(source, contains('appToastProvider'));
  });
}
