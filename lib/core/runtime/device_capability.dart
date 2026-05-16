import 'package:flutter/foundation.dart';

/// 设备性能档位（全局 runtime 使用，与播放器档位映射见 [playerPerformanceModeForTier]）。
enum DevicePerformanceTier {
  /// 低端机：播放器倾向 ultraStable，preload/session 保守。
  low,

  /// 默认档：Android stable / iOS rich（按平台）。
  standard,

  /// 高性能：iOS rich；Android 仍为 stable（不自动开 rich 动效）。
  high,
}

/// 全局设备能力快照（Phase A：多为平台 fallback，真机 RAM/型号后续 Phase B）。
class DeviceCapability {
  const DeviceCapability({
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
    required this.manufacturer,
    required this.performanceTier,
    this.physicalMemoryMb,
    this.processorCount,
  });

  /// 运行平台（与 [defaultTargetPlatform] 对齐）。
  final TargetPlatform platform;

  /// 系统版本字符串；无法读取时用 `unknown`。
  final String osVersion;

  /// 设备型号；无法读取时用平台占位（如 `android-generic`）。
  final String deviceModel;

  /// 厂商；无法读取时用 `unknown`。
  final String manufacturer;

  /// 物理内存（MB）；Phase A 常为 null。
  final int? physicalMemoryMb;

  /// CPU 逻辑核心数；Phase A 常为 null。
  final int? processorCount;

  /// 由规则或测试 override 得到的性能档位。
  final DevicePerformanceTier performanceTier;

  /// 是否低端档（语义糖，等价于 [performanceTier] == [DevicePerformanceTier.low]）。
  bool get isLowEnd => performanceTier == DevicePerformanceTier.low;

  /// Phase A 保守 fallback：Android standard，iOS high，其它 standard。
  factory DeviceCapability.fallbackForPlatform(TargetPlatform platform) {
    final tier = switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => DevicePerformanceTier.high,
      TargetPlatform.android => DevicePerformanceTier.standard,
      _ => DevicePerformanceTier.standard,
    };
    return DeviceCapability(
      platform: platform,
      osVersion: 'unknown',
      deviceModel: _fallbackModel(platform),
      manufacturer: 'unknown',
      performanceTier: tier,
      physicalMemoryMb: null,
      processorCount: null,
    );
  }

  static String _fallbackModel(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android => 'android-generic',
      TargetPlatform.iOS => 'ios-generic',
      TargetPlatform.macOS => 'macos-generic',
      _ => 'unknown',
    };
  }

  DeviceCapability copyWith({
    TargetPlatform? platform,
    String? osVersion,
    String? deviceModel,
    String? manufacturer,
    int? physicalMemoryMb,
    int? processorCount,
    DevicePerformanceTier? performanceTier,
  }) {
    return DeviceCapability(
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      deviceModel: deviceModel ?? this.deviceModel,
      manufacturer: manufacturer ?? this.manufacturer,
      physicalMemoryMb: physicalMemoryMb ?? this.physicalMemoryMb,
      processorCount: processorCount ?? this.processorCount,
      performanceTier: performanceTier ?? this.performanceTier,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DeviceCapability &&
        other.platform == platform &&
        other.osVersion == osVersion &&
        other.deviceModel == deviceModel &&
        other.manufacturer == manufacturer &&
        other.physicalMemoryMb == physicalMemoryMb &&
        other.processorCount == processorCount &&
        other.performanceTier == performanceTier;
  }

  @override
  int get hashCode => Object.hash(
    platform,
    osVersion,
    deviceModel,
    manufacturer,
    physicalMemoryMb,
    processorCount,
    performanceTier,
  );
}
