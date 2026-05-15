import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/config/app_environment.dart';

void main() {
  test('app config maps dev staging and prod base urls', () {
    expect(
      AppConfig.forEnvironment(AppEnvironment.dev).apiBaseUrl.toString(),
      'https://dev-api.example.com',
    );
    expect(
      AppConfig.forEnvironment(AppEnvironment.staging).apiBaseUrl.toString(),
      'https://staging-api.example.com',
    );
    expect(
      AppConfig.forEnvironment(AppEnvironment.prod).apiBaseUrl.toString(),
      'https://api.example.com',
    );
  });

  test('api base url override is explicit and environment scoped', () {
    final config = AppConfig.forEnvironment(
      AppEnvironment.staging,
      apiBaseUrlOverride: 'https://sandbox.example.test',
    );

    expect(config.environment, AppEnvironment.staging);
    expect(config.apiBaseUrl.toString(), 'https://sandbox.example.test');
  });
}
