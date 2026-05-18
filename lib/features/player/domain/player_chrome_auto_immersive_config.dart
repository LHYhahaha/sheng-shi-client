import '../../../../core/runtime/runtime_player_config.dart';

/// 单剧播放器 chrome 自动沉浸 UI 配置（非播放核心）。
///
/// 从 [RuntimePlayerConfig] 映射；测试可通过
/// [playerChromeAutoImmersiveConfigOverrideProvider] 覆盖延迟等字段。
class PlayerChromeAutoImmersiveConfig {
  const PlayerChromeAutoImmersiveConfig({
    required this.autoImmersiveDelay,
    required this.enableAutoImmersiveForSingleDrama,
  });

  /// 正常播放且无用户操作后，从 default chrome 切到 immersive 的等待时长。
  ///
  /// 默认 3 秒。仅单剧播放器启用；For You 不消费本配置。
  final Duration autoImmersiveDelay;

  /// 是否在单剧播放器会话中启用自动沉浸。
  ///
  /// 默认 `true`。For You 会话应在 UI 层关闭（`configureAutoImmersiveSession(enabled: false)`），
  /// 不依赖本字段单独区分 feed 类型。
  final bool enableAutoImmersiveForSingleDrama;

  factory PlayerChromeAutoImmersiveConfig.fromRuntime(
    RuntimePlayerConfig runtime,
  ) {
    return PlayerChromeAutoImmersiveConfig(
      autoImmersiveDelay: runtime.autoImmersiveDelay,
      enableAutoImmersiveForSingleDrama:
          runtime.enableAutoImmersiveForSingleDrama,
    );
  }

  static const defaults = PlayerChromeAutoImmersiveConfig(
    autoImmersiveDelay: Duration(seconds: 3),
    enableAutoImmersiveForSingleDrama: true,
  );
}
