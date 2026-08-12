import 'package:flutter/foundation.dart';

/// 远程功能开关 key 常量（避免 magic string 散落 feature 模块）。
///
/// **不包含** HLS local proxy/cache：当前已解锁 source_url 统一返回 HLS m3u8，
/// 默认启用本地代理缓存；异常时可通过
/// `--dart-define=PLAYER_DISABLE_HLS_LOCAL_PROXY=true` 紧急关闭。不得通过本表或
/// `AppRuntimeConfig` remote featureFlags 切换。
abstract final class RuntimeFeatureFlagKeys {
  /// 远程 UI 语言包。
  static const remoteLocalization = 'remote_localization';

  /// 按 locale 自动选字幕轨。
  static const subtitleByLocale = 'subtitle_by_locale';

  /// 新解锁 sheet 实验 UI。
  static const newUnlockSheet = 'new_unlock_sheet';

  /// 剧集列表走远程 API（与 `--dart-define` 并存，不替代业务状态）。
  static const apiRemoteDrama = 'api_remote_drama';

  /// 全局弹窗诊断（O5 预留；真实 remote 阶段再接）。
  static const modalDiagnostics = 'modal_diagnostics';

  /// 全局弹窗系统总开关（O5 预留；默认不通过 remote 关闭已迁移业务）。
  static const globalModalSystem = 'global_modal_system';
}

/// 远程灰度 / 实验开关表（默认全 false，显式 true 才开启）。
class RuntimeFeatureFlagConfig {
  const RuntimeFeatureFlagConfig({this.flags = const {}});

  /// 空表：所有 [isEnabled] 走 defaultValue（默认 false）。
  static const defaults = RuntimeFeatureFlagConfig();

  /// 开关表。不应存放 token、用户 id 等敏感信息；不替代会员/钱包等业务状态。
  ///
  /// 来源：remote `featureFlags` map（Phase D）。缺失 key 视为未开启。
  final Map<String, bool> flags;

  /// 查询开关；[defaultValue] 默认 false，保证远程缺失时行为安全。
  bool isEnabled(String key, {bool defaultValue = false}) {
    return flags[key] ?? defaultValue;
  }

  RuntimeFeatureFlagConfig mergeRemote(RuntimeFeatureFlagConfig remote) {
    return RuntimeFeatureFlagConfig(flags: {...flags, ...remote.flags});
  }

  RuntimeFeatureFlagConfig copyWith({Map<String, bool>? flags}) {
    return RuntimeFeatureFlagConfig(flags: flags ?? this.flags);
  }

  @override
  bool operator ==(Object other) {
    return other is RuntimeFeatureFlagConfig && mapEquals(other.flags, flags);
  }

  @override
  int get hashCode => Object.hashAll(flags.entries);
}
