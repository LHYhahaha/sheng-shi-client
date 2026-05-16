import 'package:flutter/foundation.dart';

import '../../features/player/domain/player_performance_policy.dart';
import 'device_capability.dart';

/// 全局运行时配置（Phase A：本地默认 + 可测 override；远程拉取 Phase D）。
class AppRuntimeConfig {
  const AppRuntimeConfig({
    this.playerPerformanceModeOverride,
    this.homeStartupPreloadCount,
    this.singleDramaForwardPreloadCount,
    this.singleDramaBackwardPreloadCount,
    this.forYouForwardPreloadCount,
    this.forYouBackwardPreloadCount,
    this.hlsPlaylistTimeout,
    this.hlsMaxPreloadBytes,
    this.enableRemoteLocalization = false,
    this.enableSubtitleByLocale = false,
    this.enableFeatureFlags = const {},
  });

  /// 本地安全默认值（远程缺失或失败时使用，不阻塞启动）。
  static const defaults = AppRuntimeConfig(
    homeStartupPreloadCount: 1,
    singleDramaForwardPreloadCount: 1,
    singleDramaBackwardPreloadCount: 1,
    forYouForwardPreloadCount: 1,
    hlsPlaylistTimeout: Duration(seconds: 4),
    hlsMaxPreloadBytes: 2 * 1024 * 1024,
    enableRemoteLocalization: false,
    enableSubtitleByLocale: false,
    enableFeatureFlags: {},
  );

  /// 远程 / 实验下发的播放器档位；null 表示不覆盖设备推导。
  final PlayerPerformanceMode? playerPerformanceModeOverride;

  final int? homeStartupPreloadCount;
  final int? singleDramaForwardPreloadCount;
  final int? singleDramaBackwardPreloadCount;
  final int? forYouForwardPreloadCount;
  final int? forYouBackwardPreloadCount;

  /// HLS playlist/segment 预取超时。
  final Duration? hlsPlaylistTimeout;

  /// 单条 HLS 预热字节上限。
  final int? hlsMaxPreloadBytes;

  /// 是否启用远程语言包（Phase A 仅字段，不下载）。
  final bool enableRemoteLocalization;

  /// 是否按 locale 自动开字幕（预留）。
  final bool enableSubtitleByLocale;

  /// 功能开关表（key -> enabled）；Phase A 默认空。
  final Map<String, bool> enableFeatureFlags;

  bool featureFlagEnabled(String key, {bool defaultValue = false}) {
    return enableFeatureFlags[key] ?? defaultValue;
  }

  /// 按设备档位收紧 preload 相关字段（在远程 override 之前应用）。
  AppRuntimeConfig withDeviceCapabilityRules(DeviceCapability device) {
    if (device.performanceTier != DevicePerformanceTier.low) {
      return this;
    }
    return copyWith(
      homeStartupPreloadCount: _minNullableInt(homeStartupPreloadCount, 0),
      singleDramaForwardPreloadCount: _minNullableInt(
        singleDramaForwardPreloadCount,
        0,
      ),
      singleDramaBackwardPreloadCount: _minNullableInt(
        singleDramaBackwardPreloadCount,
        0,
      ),
      forYouForwardPreloadCount: _minNullableInt(forYouForwardPreloadCount, 0),
      forYouBackwardPreloadCount: _minNullableInt(
        forYouBackwardPreloadCount,
        0,
      ),
    );
  }

  /// 合并远程片段：非 null 字段覆盖当前值。
  AppRuntimeConfig mergeRemote(AppRuntimeConfig remote) {
    return copyWith(
      playerPerformanceModeOverride:
          remote.playerPerformanceModeOverride ?? playerPerformanceModeOverride,
      homeStartupPreloadCount:
          remote.homeStartupPreloadCount ?? homeStartupPreloadCount,
      singleDramaForwardPreloadCount:
          remote.singleDramaForwardPreloadCount ??
          singleDramaForwardPreloadCount,
      singleDramaBackwardPreloadCount:
          remote.singleDramaBackwardPreloadCount ??
          singleDramaBackwardPreloadCount,
      forYouForwardPreloadCount:
          remote.forYouForwardPreloadCount ?? forYouForwardPreloadCount,
      forYouBackwardPreloadCount:
          remote.forYouBackwardPreloadCount ?? forYouBackwardPreloadCount,
      hlsPlaylistTimeout: remote.hlsPlaylistTimeout ?? hlsPlaylistTimeout,
      hlsMaxPreloadBytes: remote.hlsMaxPreloadBytes ?? hlsMaxPreloadBytes,
      enableRemoteLocalization: remote.enableRemoteLocalization,
      enableSubtitleByLocale: remote.enableSubtitleByLocale,
      enableFeatureFlags: {...enableFeatureFlags, ...remote.enableFeatureFlags},
    );
  }

  AppRuntimeConfig copyWith({
    PlayerPerformanceMode? playerPerformanceModeOverride,
    int? homeStartupPreloadCount,
    int? singleDramaForwardPreloadCount,
    int? singleDramaBackwardPreloadCount,
    int? forYouForwardPreloadCount,
    int? forYouBackwardPreloadCount,
    Duration? hlsPlaylistTimeout,
    int? hlsMaxPreloadBytes,
    bool? enableRemoteLocalization,
    bool? enableSubtitleByLocale,
    Map<String, bool>? enableFeatureFlags,
    bool clearPlayerPerformanceModeOverride = false,
  }) {
    return AppRuntimeConfig(
      playerPerformanceModeOverride: clearPlayerPerformanceModeOverride
          ? null
          : playerPerformanceModeOverride ?? this.playerPerformanceModeOverride,
      homeStartupPreloadCount:
          homeStartupPreloadCount ?? this.homeStartupPreloadCount,
      singleDramaForwardPreloadCount:
          singleDramaForwardPreloadCount ?? this.singleDramaForwardPreloadCount,
      singleDramaBackwardPreloadCount:
          singleDramaBackwardPreloadCount ??
          this.singleDramaBackwardPreloadCount,
      forYouForwardPreloadCount:
          forYouForwardPreloadCount ?? this.forYouForwardPreloadCount,
      forYouBackwardPreloadCount:
          forYouBackwardPreloadCount ?? this.forYouBackwardPreloadCount,
      hlsPlaylistTimeout: hlsPlaylistTimeout ?? this.hlsPlaylistTimeout,
      hlsMaxPreloadBytes: hlsMaxPreloadBytes ?? this.hlsMaxPreloadBytes,
      enableRemoteLocalization:
          enableRemoteLocalization ?? this.enableRemoteLocalization,
      enableSubtitleByLocale:
          enableSubtitleByLocale ?? this.enableSubtitleByLocale,
      enableFeatureFlags: enableFeatureFlags ?? this.enableFeatureFlags,
    );
  }

  static int? _minNullableInt(int? value, int cap) {
    if (value == null) {
      return cap;
    }
    return value < cap ? value : cap;
  }

  @override
  bool operator ==(Object other) {
    return other is AppRuntimeConfig &&
        other.playerPerformanceModeOverride == playerPerformanceModeOverride &&
        other.homeStartupPreloadCount == homeStartupPreloadCount &&
        other.singleDramaForwardPreloadCount ==
            singleDramaForwardPreloadCount &&
        other.singleDramaBackwardPreloadCount ==
            singleDramaBackwardPreloadCount &&
        other.forYouForwardPreloadCount == forYouForwardPreloadCount &&
        other.forYouBackwardPreloadCount == forYouBackwardPreloadCount &&
        other.hlsPlaylistTimeout == hlsPlaylistTimeout &&
        other.hlsMaxPreloadBytes == hlsMaxPreloadBytes &&
        other.enableRemoteLocalization == enableRemoteLocalization &&
        other.enableSubtitleByLocale == enableSubtitleByLocale &&
        mapEquals(other.enableFeatureFlags, enableFeatureFlags);
  }

  @override
  int get hashCode => Object.hash(
    playerPerformanceModeOverride,
    homeStartupPreloadCount,
    singleDramaForwardPreloadCount,
    singleDramaBackwardPreloadCount,
    forYouForwardPreloadCount,
    forYouBackwardPreloadCount,
    hlsPlaylistTimeout,
    hlsMaxPreloadBytes,
    enableRemoteLocalization,
    enableSubtitleByLocale,
    enableFeatureFlags,
  );
}
