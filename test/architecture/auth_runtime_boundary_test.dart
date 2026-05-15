import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth runtime coordinators stay out of UI and feature controllers', () {
    final offenders = <String>[];
    final roots = [Directory('lib/features'), Directory('lib/app')];
    const forbiddenTokens = [
      'core/auth/auth_token_store.dart',
      'core/auth/auth_refresh_coordinator.dart',
      'core/auth/session_cleanup_coordinator.dart',
      'authTokenStoreProvider',
      'AuthTokenStore',
      'AuthRefreshCoordinator',
      'authRefreshCoordinatorProvider',
      'SessionCleanupCoordinator',
      'sessionCleanupCoordinatorProvider',
    ];

    for (final root in roots) {
      if (!root.existsSync()) continue;

      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final path = entity.path;
        final isFeatureUiOrController =
            path.contains('/presentation/') ||
            path.contains('/application/') ||
            path.startsWith('lib/app/');
        if (!isFeatureUiOrController) continue;

        final source = entity.readAsStringSync();
        for (final token in forbiddenTokens) {
          if (source.contains(token)) {
            offenders.add('$path uses $token');
          }
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
