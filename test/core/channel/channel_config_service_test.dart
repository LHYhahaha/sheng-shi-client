import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drama_client/core/channel/channel_config_service.dart';

class MockMethodChannel extends Mock implements MethodChannel {}

void main() {
  group('ChannelConfigService', () {
    late ChannelConfigService service;
    late MethodChannel originalChannel;

    setUp(() {
      service = ChannelConfigService();
    });

    tearDown(() {
      // 重置缓存
      service.getChannelConfig();
    });

    test('returns null config when MethodChannel fails', () async {
      // 在非Android平台或没有配置时，应该返回空配置
      final config = await service.getChannelConfig();
      
      expect(config, isA<ChannelConfig>());
      expect(config.hasConfig, isFalse);
    });

    test('ChannelConfig.hasConfig returns true when any field is not null', () {
      const config1 = ChannelConfig(channelFlag: 'test');
      expect(config1.hasConfig, isTrue);

      const config2 = ChannelConfig(merchantId: '1');
      expect(config2.hasConfig, isTrue);

      const config3 = ChannelConfig(vestPkgId: '1001');
      expect(config3.hasConfig, isTrue);

      const config4 = ChannelConfig();
      expect(config4.hasConfig, isFalse);
    });

    test('ChannelConfig.toHeaders returns correct headers', () {
      const config = ChannelConfig(
        channelFlag: 'test',
        merchantId: '1',
        vestPkgId: '1001',
      );

      final headers = config.toHeaders();

      expect(headers['X-Channel-Flag'], 'test');
      expect(headers['X-Merchant-Id'], '1');
      expect(headers['X-Vest-Pkg-Id'], '1001');
    });

    test('ChannelConfig.toHeaders returns empty map when all fields are null', () {
      const config = ChannelConfig();

      final headers = config.toHeaders();

      expect(headers, isEmpty);
    });

    test('ChannelConfig.toHeaders skips null fields', () {
      const config = ChannelConfig(
        channelFlag: 'test',
        merchantId: null,
        vestPkgId: '1001',
      );

      final headers = config.toHeaders();

      expect(headers.containsKey('X-Channel-Flag'), isTrue);
      expect(headers.containsKey('X-Merchant-Id'), isFalse);
      expect(headers.containsKey('X-Vest-Pkg-Id'), isTrue);
    });
  });
}
