import 'package:drama_client/core/config/app_environment.dart';
import 'package:drama_client/core/network/remote_api_module.dart';
import 'package:drama_client/core/network/remote_api_readiness_guard.dart';
import 'package:drama_client/core/network/remote_api_switches.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppConfig stagingConfig({String host = 'api.staging.yushi.example'}) {
    return AppConfig(
      environment: AppEnvironment.staging,
      apiBaseUrl: Uri.parse('https://$host'),
    );
  }

  group('RemoteApiSwitches', () {
    test('fromEnvironment defaults to all disabled', () {
      final switches = RemoteApiSwitches.fromEnvironment();
      expect(switches.anyEnabled, isFalse);
      expect(switches.dramaEnabled, isFalse);
    });

    test('dramaEnabled includes legacy USE_REMOTE_API only for drama', () {
      const switches = RemoteApiSwitches(legacyUseRemoteApi: true);
      expect(switches.dramaEnabled, isTrue);
      expect(switches.player, isFalse);
    });
  });

  group('RemoteApiReadinessGuard', () {
    test('staging drama only is valid with real base url', () {
      final report = RemoteApiReadinessGuard.validate(
        config: stagingConfig(),
        requested: const RemoteApiSwitches(drama: true),
      );

      expect(report.isValid, isTrue);
      expect(report.enabledModules, [RemoteApiModule.drama]);
      expect(report.effective.dramaEnabled, isTrue);
      expect(report.blockedModules, isEmpty);
    });

    test('placeholder example.com host errors when remote enabled', () {
      final report = RemoteApiReadinessGuard.validate(
        config: AppConfig.forEnvironment(AppEnvironment.staging),
        requested: const RemoteApiSwitches(drama: true),
      );

      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.contains('placeholder')), isTrue);
      expect(report.effective.anyEnabled, isFalse);
    });

    test('prod blocks high-risk modules with errors', () {
      final report = RemoteApiReadinessGuard.validate(
        config: stagingConfig(
          host: 'api.prod.yushi.example',
        ).copyWith(environment: AppEnvironment.prod),
        requested: const RemoteApiSwitches(
          auth: true,
          store: true,
          entitlement: true,
        ),
      );

      expect(report.isValid, isFalse);
      expect(report.blockedModules, contains(RemoteApiModule.auth));
      expect(report.effective.auth, isFalse);
      expect(
        report.errors.any((e) => e.contains('USE_REMOTE_AUTH_API')),
        isTrue,
      );
    });

    test('prod blocks medium-risk modules', () {
      final report = RemoteApiReadinessGuard.validate(
        config: AppConfig(
          environment: AppEnvironment.prod,
          apiBaseUrl: Uri.parse('https://api.prod.yushi.example'),
        ),
        requested: const RemoteApiSwitches(player: true),
      );

      expect(report.isValid, isFalse);
      expect(report.effective.player, isFalse);
    });

    test('staging store wallet entitlement produce errors', () {
      final report = RemoteApiReadinessGuard.validate(
        config: stagingConfig(),
        requested: const RemoteApiSwitches(
          store: true,
          wallet: true,
          entitlement: true,
        ),
      );

      expect(report.isValid, isFalse);
      expect(report.blockedModules, contains(RemoteApiModule.store));
      expect(report.effective.store, isFalse);
    });

    test('staging player enables with warning', () {
      final report = RemoteApiReadinessGuard.validate(
        config: stagingConfig(),
        requested: const RemoteApiSwitches(player: true),
      );

      expect(report.isValid, isTrue);
      expect(report.effective.player, isTrue);
      expect(report.warnings, isNotEmpty);
    });

    test('validateOrThrow throws RemoteApiReadinessException', () {
      expect(
        () => RemoteApiReadinessGuard.validateOrThrow(
          config: AppConfig.forEnvironment(AppEnvironment.staging),
          requested: const RemoteApiSwitches(auth: true),
        ),
        throwsA(isA<RemoteApiReadinessException>()),
      );
    });

    test('legacy USE_REMOTE_API adds warning', () {
      final report = RemoteApiReadinessGuard.validate(
        config: stagingConfig(),
        requested: const RemoteApiSwitches(legacyUseRemoteApi: true),
      );

      expect(report.effective.dramaEnabled, isTrue);
      expect(report.warnings.any((w) => w.contains('USE_REMOTE_API')), isTrue);
    });
  });
}

extension on AppConfig {
  AppConfig copyWith({AppEnvironment? environment, Uri? apiBaseUrl}) {
    return AppConfig(
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
    );
  }
}
