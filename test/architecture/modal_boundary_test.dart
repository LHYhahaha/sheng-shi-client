import 'dart:io';

import 'package:drama_client/core/modal/app_modal_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core/modal must not import features', () {
    final modalDir = Directory('lib/core/modal');
    expect(modalDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in modalDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
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

  test('ConfirmResult is typed and not a bare bool', () {
    const result = ConfirmResult.confirmed;
    expect(result, isA<ConfirmResult>());
    expect(result.isConfirmed, isTrue);
    expect(result, isNot(isA<bool>()));
  });

  test('player unlock sheets use AppModal not local showModalBottomSheet', () {
    final source = File(
      'lib/features/player/presentation/pages/player_page.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('PlayerCoinUnlockSheet')));
    expect(source, isNot(contains('PlayerRechargeUnlockSheet')));
    expect(source, contains('playerUnlockModalCoordinatorProvider'));
    expect(source, contains('PlayerDetailSheet'));
    expect(source, contains('showModalBottomSheet'));
  });

  test('legacy showModalBottomSheet whitelist for store and membership', () {
    const whitelist = <String>[
      'lib/features/store/presentation/pages/store_page.dart',
      'lib/features/membership/presentation/pages/membership_page.dart',
    ];

    for (final path in whitelist) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'missing whitelist file: $path',
      );
      expect(
        file.readAsStringSync(),
        contains('showModalBottomSheet'),
        reason: '$path expected to keep legacy sheet until O4',
      );
    }
  });
}
