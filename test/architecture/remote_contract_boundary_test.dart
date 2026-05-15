import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'remote DTO and datasource layers do not leak into UI/controller code',
    () {
      final offenders = <String>[];
      final featureRoot = Directory('lib/features');

      for (final entity in featureRoot.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        final isApplicationOrPresentation =
            path.contains('/application/') || path.contains('/presentation/');
        if (!isApplicationOrPresentation) continue;

        final source = entity.readAsStringSync();
        final leaksRemoteContract =
            source.contains('/data/dto/') ||
            source.contains('/data/remote/') ||
            source.contains('remote_') ||
            source.contains('RemoteDataSource') ||
            source.contains('RemoteRepository');
        if (leaksRemoteContract) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty);
    },
  );
}
