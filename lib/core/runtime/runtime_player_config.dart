import 'device_capability.dart';
import 'runtime_performance_mode.dart';

/// 播放器与 HLS 预加载相关的全局 runtime 配置（不含 UI / 业务 sheet 逻辑）。
class RuntimePlayerConfig {
  const RuntimePlayerConfig({
    this.performanceModeOverride,
    this.homeStartupHlsPreloadCount,
    this.singleDramaForwardHlsPreloadCount,
    this.singleDramaBackwardHlsPreloadCount,
    this.forYouForwardHlsPreloadCount,
    this.forYouBackwardHlsPreloadCount,
    this.hlsPlaylistTimeout,
    this.hlsMaxPreloadBytes,
    this.enablePlaybackTimingLogs = false,
    this.enableRebuildLogs = false,
  });

  /// 本地安全默认：最小 HLS 预热、保守超时，不扩大 media session 窗口。
  ///
  /// 远程缺字段时保持此默认；启动失败回退亦使用本常量。
  static const defaults = RuntimePlayerConfig(
    homeStartupHlsPreloadCount: 1,
    singleDramaForwardHlsPreloadCount: 1,
    singleDramaBackwardHlsPreloadCount: 1,
    forYouForwardHlsPreloadCount: 1,
    forYouBackwardHlsPreloadCount: 1,
    hlsPlaylistTimeout: Duration(seconds: 4),
    hlsMaxPreloadBytes: 2 * 1024 * 1024,
    enablePlaybackTimingLogs: false,
    enableRebuildLogs: false,
  );

  /// 远程 / 实验下发的播放器档位；null 表示不覆盖设备推导。
  ///
  /// 风险：误配 rich 可能在低端 Android 上加重 surface 动画成本。
  /// 来源：未来 `AppRuntimeRepository` remote JSON `player.performanceMode`。
  final RuntimePerformanceMode? performanceModeOverride;

  /// 首页启动阶段 HLS HTTP 预加载条数（playlist/segment，不持有播放器实例）。
  ///
  /// 默认 1：与首页轻量启动一致。增大增加弱网流量与首屏带宽竞争。
  /// 不影响 prepared/retained session 数量。可远程调优，低端机规则会压到 0。
  final int? homeStartupHlsPreloadCount;

  /// 单剧 feed 向后 HLS HTTP 预加载条数。
  ///
  /// 默认 1。仅网络预热，非 media prepare。快速滑走可能浪费带宽。
  final int? singleDramaForwardHlsPreloadCount;

  /// 单剧 feed 向前 HLS HTTP 预加载条数。
  ///
  /// 默认 1。回滑主路径仍依赖 retained session，不宜盲目调大。
  final int? singleDramaBackwardHlsPreloadCount;

  /// For You 向后 HLS HTTP 预加载条数。
  ///
  /// 默认 1。增大可能改善连续下滑，但会与当前播放抢 CDN。
  final int? forYouForwardHlsPreloadCount;

  /// For You 向前 HLS HTTP 预加载条数。
  ///
  /// 默认 1。用户很少连续上滑，调大收益有限。
  final int? forYouBackwardHlsPreloadCount;

  /// HLS playlist/segment 预取超时。
  ///
  /// 默认 4s，与现有 preheater 一致。过长会让过期 pending 占用网络。
  /// 来源：remote `player.hlsPlaylistTimeoutMs`（Phase D）。
  final Duration? hlsPlaylistTimeout;

  /// 单条 HLS 预热字节上限。
  ///
  /// 默认 2 MiB。增大可能改善大首段，但信息流快速滑走会浪费流量。
  /// ultraStable 下不会被 remote 意外放大（见 player preload merge）。
  final int? hlsMaxPreloadBytes;

  /// 是否在 release 保留播放链路 timing 日志。
  ///
  /// 默认 false：避免量产日志噪声。调试 / 灰度可远程开启。
  final bool enablePlaybackTimingLogs;

  /// 是否输出 Player 重建/overlay 诊断日志。
  ///
  /// 默认 false。仅诊断滑动卡顿；开启会增加 I/O。
  final bool enableRebuildLogs;

  /// 低端机收紧 HLS 预加载数量（在 remote merge 之后仍会再次应用）。
  RuntimePlayerConfig withDeviceCapabilityRules(DeviceCapability device) {
    if (device.performanceTier != DevicePerformanceTier.low) {
      return this;
    }
    return copyWith(
      homeStartupHlsPreloadCount: _minNullableInt(
        homeStartupHlsPreloadCount,
        0,
      ),
      singleDramaForwardHlsPreloadCount: _minNullableInt(
        singleDramaForwardHlsPreloadCount,
        0,
      ),
      singleDramaBackwardHlsPreloadCount: _minNullableInt(
        singleDramaBackwardHlsPreloadCount,
        0,
      ),
      forYouForwardHlsPreloadCount: _minNullableInt(
        forYouForwardHlsPreloadCount,
        0,
      ),
      forYouBackwardHlsPreloadCount: _minNullableInt(
        forYouBackwardHlsPreloadCount,
        0,
      ),
    );
  }

  /// 合并远程片段：仅非 null 字段覆盖。
  RuntimePlayerConfig mergeRemote(RuntimePlayerConfig remote) {
    return copyWith(
      performanceModeOverride:
          remote.performanceModeOverride ?? performanceModeOverride,
      homeStartupHlsPreloadCount:
          remote.homeStartupHlsPreloadCount ?? homeStartupHlsPreloadCount,
      singleDramaForwardHlsPreloadCount:
          remote.singleDramaForwardHlsPreloadCount ??
          singleDramaForwardHlsPreloadCount,
      singleDramaBackwardHlsPreloadCount:
          remote.singleDramaBackwardHlsPreloadCount ??
          singleDramaBackwardHlsPreloadCount,
      forYouForwardHlsPreloadCount:
          remote.forYouForwardHlsPreloadCount ?? forYouForwardHlsPreloadCount,
      forYouBackwardHlsPreloadCount:
          remote.forYouBackwardHlsPreloadCount ?? forYouBackwardHlsPreloadCount,
      hlsPlaylistTimeout: remote.hlsPlaylistTimeout ?? hlsPlaylistTimeout,
      hlsMaxPreloadBytes: remote.hlsMaxPreloadBytes ?? hlsMaxPreloadBytes,
      enablePlaybackTimingLogs: remote.enablePlaybackTimingLogs,
      enableRebuildLogs: remote.enableRebuildLogs,
    );
  }

  RuntimePlayerConfig copyWith({
    RuntimePerformanceMode? performanceModeOverride,
    int? homeStartupHlsPreloadCount,
    int? singleDramaForwardHlsPreloadCount,
    int? singleDramaBackwardHlsPreloadCount,
    int? forYouForwardHlsPreloadCount,
    int? forYouBackwardHlsPreloadCount,
    Duration? hlsPlaylistTimeout,
    int? hlsMaxPreloadBytes,
    bool? enablePlaybackTimingLogs,
    bool? enableRebuildLogs,
    bool clearPerformanceModeOverride = false,
  }) {
    return RuntimePlayerConfig(
      performanceModeOverride: clearPerformanceModeOverride
          ? null
          : performanceModeOverride ?? this.performanceModeOverride,
      homeStartupHlsPreloadCount:
          homeStartupHlsPreloadCount ?? this.homeStartupHlsPreloadCount,
      singleDramaForwardHlsPreloadCount:
          singleDramaForwardHlsPreloadCount ??
          this.singleDramaForwardHlsPreloadCount,
      singleDramaBackwardHlsPreloadCount:
          singleDramaBackwardHlsPreloadCount ??
          this.singleDramaBackwardHlsPreloadCount,
      forYouForwardHlsPreloadCount:
          forYouForwardHlsPreloadCount ?? this.forYouForwardHlsPreloadCount,
      forYouBackwardHlsPreloadCount:
          forYouBackwardHlsPreloadCount ?? this.forYouBackwardHlsPreloadCount,
      hlsPlaylistTimeout: hlsPlaylistTimeout ?? this.hlsPlaylistTimeout,
      hlsMaxPreloadBytes: hlsMaxPreloadBytes ?? this.hlsMaxPreloadBytes,
      enablePlaybackTimingLogs:
          enablePlaybackTimingLogs ?? this.enablePlaybackTimingLogs,
      enableRebuildLogs: enableRebuildLogs ?? this.enableRebuildLogs,
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
    return other is RuntimePlayerConfig &&
        other.performanceModeOverride == performanceModeOverride &&
        other.homeStartupHlsPreloadCount == homeStartupHlsPreloadCount &&
        other.singleDramaForwardHlsPreloadCount ==
            singleDramaForwardHlsPreloadCount &&
        other.singleDramaBackwardHlsPreloadCount ==
            singleDramaBackwardHlsPreloadCount &&
        other.forYouForwardHlsPreloadCount == forYouForwardHlsPreloadCount &&
        other.forYouBackwardHlsPreloadCount == forYouBackwardHlsPreloadCount &&
        other.hlsPlaylistTimeout == hlsPlaylistTimeout &&
        other.hlsMaxPreloadBytes == hlsMaxPreloadBytes &&
        other.enablePlaybackTimingLogs == enablePlaybackTimingLogs &&
        other.enableRebuildLogs == enableRebuildLogs;
  }

  @override
  int get hashCode => Object.hash(
    performanceModeOverride,
    homeStartupHlsPreloadCount,
    singleDramaForwardHlsPreloadCount,
    singleDramaBackwardHlsPreloadCount,
    forYouForwardHlsPreloadCount,
    forYouBackwardHlsPreloadCount,
    hlsPlaylistTimeout,
    hlsMaxPreloadBytes,
    enablePlaybackTimingLogs,
    enableRebuildLogs,
  );
}
