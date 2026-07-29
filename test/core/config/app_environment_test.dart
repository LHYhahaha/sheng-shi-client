import 'package:flutter_test/flutter_test.dart';

import 'package:drama_client/core/config/app_environment.dart';

void main() {
  test('app config maps dev staging and prod base urls', () {
    expect(
      AppConfig.forEnvironment(AppEnvironment.dev).apiBaseUrl.toString(),
      'https://gateway-api.8y4w2vxvdffmd83.xyz',
    );
    expect(
      AppConfig.forEnvironment(AppEnvironment.staging).apiBaseUrl.toString(),
      'https://staging-api.example.com',
    );
    expect(
      AppConfig.forEnvironment(AppEnvironment.prod).apiBaseUrl.toString(),
      'https://gateway-api.3ype43hnuvw82h67e523.xyz',
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

  test('help URL maps environment and current language', () {
    expect(
      AppConfig.forEnvironment(
        AppEnvironment.dev,
      ).helpUrlForLanguage('en').toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/app/?lang=en#/help',
    );
    expect(
      AppConfig.forEnvironment(
        AppEnvironment.prod,
      ).helpUrlForLanguage('zh').toString(),
      'https://juan365drama.com/app/?lang=zh#/help',
    );
  });

  test('legal and share URLs map environment and current language', () {
    final devConfig = AppConfig.forEnvironment(AppEnvironment.dev);
    expect(
      devConfig.privacyPolicyUrlForLanguage('en').toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/legal/privacy/index.html?lang=en',
    );
    expect(
      devConfig.termsOfUseUrlForLanguage('zh').toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/legal/terms/index.html?lang=zh',
    );
    expect(
      devConfig.shareUrl(dramaId: '1506', languageCode: 'zh').toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/share/?drama_id=1506&lang=zh',
    );
    expect(
      AppConfig.forEnvironment(
        AppEnvironment.prod,
      ).privacyPolicyUrlForLanguage('en').toString(),
      'https://juan365drama.com/legal/privacy/index.html?lang=en',
    );
  });
}
