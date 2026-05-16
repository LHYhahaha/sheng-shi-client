import 'device_capability.dart';
import 'runtime_feature_flag_config.dart';
import 'runtime_localization_config.dart';
import 'runtime_player_config.dart';

/// 全局运行时配置根对象（Phase A.1：分组结构；远程拉取 Phase D）。
///
/// 所有运行时策略应从 `lib/core/runtime` 读取，feature 模块只做 domain 映射。
class AppRuntimeConfig {
  const AppRuntimeConfig({
    required this.player,
    required this.localization,
    required this.featureFlags,
  });

  /// 本地安全默认值（远程缺失 / 失败 / null 时回退，不阻塞启动）。
  static const defaults = AppRuntimeConfig(
    player: RuntimePlayerConfig.defaults,
    localization: RuntimeLocalizationConfig.defaults,
    featureFlags: RuntimeFeatureFlagConfig.defaults,
  );

  /// 播放器与 HLS 预加载相关配置。
  final RuntimePlayerConfig player;

  /// 多语言包与内容本地化元数据（当前不下载、不改 l10n）。
  final RuntimeLocalizationConfig localization;

  /// 远程灰度与实验开关。
  final RuntimeFeatureFlagConfig featureFlags;

  /// 按设备档位收紧 [player] 预加载（主要作用于低端机）。
  AppRuntimeConfig withDeviceCapabilityRules(DeviceCapability device) {
    return copyWith(player: player.withDeviceCapabilityRules(device));
  }

  /// 合并远程片段：各分组仅非 null / 显式字段覆盖；缺字段保留当前值。
  AppRuntimeConfig mergeRemote(AppRuntimeConfig remote) {
    return copyWith(
      player: player.mergeRemote(remote.player),
      localization: localization.mergeRemote(remote.localization),
      featureFlags: featureFlags.mergeRemote(remote.featureFlags),
    );
  }

  AppRuntimeConfig copyWith({
    RuntimePlayerConfig? player,
    RuntimeLocalizationConfig? localization,
    RuntimeFeatureFlagConfig? featureFlags,
  }) {
    return AppRuntimeConfig(
      player: player ?? this.player,
      localization: localization ?? this.localization,
      featureFlags: featureFlags ?? this.featureFlags,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppRuntimeConfig &&
        other.player == player &&
        other.localization == localization &&
        other.featureFlags == featureFlags;
  }

  @override
  int get hashCode => Object.hash(player, localization, featureFlags);
}
