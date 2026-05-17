import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 防止 remote DTO 回退到危险默认值（Post-RC A6）。
void main() {
  test('remote dto files avoid dangerous unlock and enabled defaults', () {
    final dtoRoot = Directory('lib/features');
    final offenders = <String>[];
    final patterns = <RegExp>[
      RegExp(r"unlockType.*\?\?\s*'free'"),
      RegExp(r"unlockType.*fallback:\s*'coins'"),
      RegExp(r"enabled:\s*map\['enabled'\]\s*!=\s*false"),
      RegExp(r"status.*fallback:\s*'created'"),
      RegExp(
        r"map\['result'\] is String \? map\['result'\] as String : 'success'",
      ),
    ];

    for (final entity in dtoRoot.listSync(recursive: true)) {
      if (entity is! File || !entity.path.contains('/data/dto/')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final pattern in patterns) {
        if (pattern.hasMatch(source)) {
          offenders.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('player remote decoders do not fabricate empty dto on wrong type', () {
    final sources = [
      'lib/features/player/data/remote/player_remote_data_source.dart',
      'lib/features/player/data/remote/playback_source_remote_data_source.dart',
    ];

    for (final path in sources) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('return const PlayerContentDto')));
      expect(source, isNot(contains('return const PlaybackSourceDto')));
    }
  });
}
