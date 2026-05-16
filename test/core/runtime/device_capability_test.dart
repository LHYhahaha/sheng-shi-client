import 'package:drama_client/core/runtime/device_capability.dart';
import 'package:drama_client/core/runtime/device_capability_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallbackForPlatform Android 为 standard', () {
    final capability = DeviceCapability.fallbackForPlatform(
      TargetPlatform.android,
    );
    expect(capability.performanceTier, DevicePerformanceTier.standard);
    expect(capability.deviceModel, 'android-generic');
    expect(capability.physicalMemoryMb, isNull);
  });

  test('fallbackForPlatform iOS 为 high', () {
    final capability = DeviceCapability.fallbackForPlatform(TargetPlatform.iOS);
    expect(capability.performanceTier, DevicePerformanceTier.high);
  });

  test('devicePerformanceTierOverrideProvider 可覆盖为 low', () {
    final container = ProviderContainer(
      overrides: [
        devicePerformanceTierOverrideProvider.overrideWithValue(
          DevicePerformanceTier.low,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(deviceCapabilityProvider).performanceTier,
      DevicePerformanceTier.low,
    );
    expect(container.read(deviceCapabilityProvider).isLowEnd, isTrue);
  });

  test('deviceCapabilityOverrideProvider 覆盖完整快照', () {
    const custom = DeviceCapability(
      platform: TargetPlatform.android,
      osVersion: '14',
      deviceModel: 'SM-A145F',
      manufacturer: 'samsung',
      performanceTier: DevicePerformanceTier.low,
      physicalMemoryMb: 3072,
      processorCount: 8,
    );
    final container = ProviderContainer(
      overrides: [deviceCapabilityOverrideProvider.overrideWithValue(custom)],
    );
    addTearDown(container.dispose);

    expect(container.read(deviceCapabilityProvider), custom);
  });
}
