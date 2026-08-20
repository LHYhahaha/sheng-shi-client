import 'dart:convert';

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
      AppConfig.forEnvironment(AppEnvironment.dev)
          .helpUrlForLanguage(
            'en',
            userId: 'user-1',
            channelId: 'channel-a',
            merchantId: 'merchant-9',
            previousPage: 'my_page',
          )
          .toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/app/?lang=en&user_id=user-1&channel_id=channel-a&merchant_id=merchant-9&previous_page=my_page#/help',
    );
    expect(
      AppConfig.forEnvironment(
        AppEnvironment.prod,
      ).helpUrlForLanguage('zh').toString(),
      'https://juan365drama.com/app/?lang=zh&user_id&channel_id&merchant_id&previous_page#/help',
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
      devConfig
          .shareUrl(
            dramaId: '1506',
            languageCode: 'zh',
            userId: 'user-1',
            channelId: 'channel-a',
            merchantId: 'merchant-9',
            shareMethod: 'facebook',
          )
          .toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/share/?lang=zh&user_id=user-1&channel_id=channel-a&merchant_id=merchant-9&drama_id=1506&share_method=facebook',
    );
    final facebookShareUrl = devConfig.facebookShareUrl(
      dramaId: '1506',
      languageCode: 'zh',
      userId: 'user-1',
      channelId: 'channel-a',
      merchantId: 'merchant-9',
    );
    expect(facebookShareUrl.path, '/share/');
    expect(facebookShareUrl.queryParameters.keys, {'_sp'});
    final packed = facebookShareUrl.queryParameters['_sp']!;
    expect(
      utf8.decode(base64Url.decode(base64Url.normalize(packed))),
      'drama_id=1506&lang=zh&user_id=user-1&channel_id=channel-a&merchant_id=merchant-9&share_method=facebook',
    );
    expect(
      devConfig
          .giftVipUrl(
            languageCode: 'en',
            userId: 'user-1',
            channelId: 'channel-a',
            merchantId: 'merchant-9',
            shareMethod: 'copy_link',
            giftLinkId: 'gift-1',
            grantTempVipDays: '3',
          )
          .toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/gift/vip/?lang=en&user_id=user-1&channel_id=channel-a&merchant_id=merchant-9&share_method=copy_link&gift_link_id=gift-1&grant_temp_vip_days=3',
    );
    expect(
      devConfig
          .giftDramaUrl(
            languageCode: 'en',
            userId: 'user-1',
            channelId: 'channel-a',
            merchantId: 'merchant-9',
            shareMethod: 'facebook',
            giftLinkId: 'gift-2',
          )
          .toString(),
      'https://drama-wave.8y4w2vxvdffmd83.xyz/gift/drama/?lang=en&user_id=user-1&channel_id=channel-a&merchant_id=merchant-9&share_method=facebook&gift_link_id=gift-2',
    );
    expect(
      AppConfig.forEnvironment(
        AppEnvironment.prod,
      ).privacyPolicyUrlForLanguage('en').toString(),
      'https://juan365drama.com/legal/privacy/index.html?lang=en',
    );
  });
}
