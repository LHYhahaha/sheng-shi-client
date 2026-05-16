import 'package:drama_client/core/runtime/device_capability.dart';
import 'package:drama_client/core/runtime/device_performance_tier_rules.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveDevicePerformanceTier', () {
    test('Android SM-A145F -> low', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          manufacturer: 'samsung',
          model: 'SM-A145F',
        ),
        DevicePerformanceTier.low,
      );
    });

    test('Android SM-A14 / Galaxy A14 -> low（大小写不敏感）', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'galaxy a14 5g',
        ),
        DevicePerformanceTier.low,
      );
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'SM-A14F',
        ),
        DevicePerformanceTier.low,
      );
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          manufacturer: 'SAMSUNG',
          model: 'sm-a145f',
        ),
        DevicePerformanceTier.low,
      );
    });

    test('Android SM-A146 不误判为 A14 系列 low', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          manufacturer: 'samsung',
          model: 'SM-A146B',
        ),
        DevicePerformanceTier.standard,
      );
    });

    test('Android unknown model -> standard', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'Pixel 8',
        ),
        DevicePerformanceTier.standard,
      );
    });

    test('missing model/manufacturer -> Android standard', () {
      expect(
        resolveDevicePerformanceTier(platform: TargetPlatform.android),
        DevicePerformanceTier.standard,
      );
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          manufacturer: 'unknown',
          model: 'android-generic',
        ),
        DevicePerformanceTier.standard,
      );
    });

    test('iOS any model -> high，不 low', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.iOS,
          model: 'SM-A145F',
        ),
        DevicePerformanceTier.high,
      );
    });

    test('RAM <= 3GB -> low', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'Pixel 8',
          physicalMemoryMb: 3072,
        ),
        DevicePerformanceTier.low,
      );
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'Pixel 8',
          physicalMemoryMb: 2048,
        ),
        DevicePerformanceTier.low,
      );
    });

    test('RAM unknown 不因 RAM 单独 low', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'Pixel 8',
        ),
        DevicePerformanceTier.standard,
      );
    });

    test('RAM 4GB 档 -> standard', () {
      expect(
        resolveDevicePerformanceTier(
          platform: TargetPlatform.android,
          model: 'Pixel 8',
          physicalMemoryMb: 4096,
        ),
        DevicePerformanceTier.standard,
      );
    });
  });
}
