/// 多语言与内容本地化相关的 runtime 元数据（Phase A.1 仅结构，不下载、不改 l10n 生成）。
class RuntimeLocalizationConfig {
  const RuntimeLocalizationConfig({
    this.enableRemoteLanguagePack = false,
    this.languagePackVersion,
    this.languagePackUrl,
    this.enableContentLocalization = false,
    this.enableSubtitleByLocale = false,
    this.subtitleFallbackLocale,
  });

  /// 默认关闭远程语言包：固定 UI 仍走 codegen `AppLocalizations`。
  static const defaults = RuntimeLocalizationConfig();

  /// 是否启用远程 UI 语言包下载与切换。
  ///
  /// 与 [enableContentLocalization] 不同：前者是客户端固定文案包，后者是剧集标题/简介等
  /// 由内容接口按 `Lang` 返回。默认 false，避免启动依赖网络。
  /// 来源：remote `localization.enableRemoteLanguagePack`（Phase E）。
  final bool enableRemoteLanguagePack;

  /// 当前应使用的远程语言包版本号（如 `1.0.4`）。
  ///
  /// null 表示未下发；后续与本地 fixed bundle 版本比较决定是否下载。
  /// 来源：服务端配置中心。
  final String? languagePackVersion;

  /// 远程语言包 JSON 地址。
  ///
  /// Phase A.1 不请求此 URL。必须 HTTPS，且需校验签名/版本（后续 Phase）。
  final String? languagePackUrl;

  /// 是否请求内容接口的多语言字段（剧集元数据、字幕轨等）。
  ///
  /// 不等于 UI 语言包。默认 false：mock 阶段仍用本地 seed。
  final bool enableContentLocalization;

  /// 是否按当前客户端 locale 自动选择字幕轨。
  ///
  /// 属于播放器展示策略，不等于内容 API 的 `Lang` 参数。默认 false。
  final bool enableSubtitleByLocale;

  /// 字幕匹配失败时的回退 locale（如 `en`）。
  ///
  /// 仅当 [enableSubtitleByLocale] 为 true 时生效。
  final String? subtitleFallbackLocale;

  RuntimeLocalizationConfig mergeRemote(RuntimeLocalizationConfig remote) {
    return copyWith(
      enableRemoteLanguagePack: remote.enableRemoteLanguagePack,
      languagePackVersion: remote.languagePackVersion ?? languagePackVersion,
      languagePackUrl: remote.languagePackUrl ?? languagePackUrl,
      enableContentLocalization: remote.enableContentLocalization,
      enableSubtitleByLocale: remote.enableSubtitleByLocale,
      subtitleFallbackLocale:
          remote.subtitleFallbackLocale ?? subtitleFallbackLocale,
    );
  }

  RuntimeLocalizationConfig copyWith({
    bool? enableRemoteLanguagePack,
    String? languagePackVersion,
    String? languagePackUrl,
    bool? enableContentLocalization,
    bool? enableSubtitleByLocale,
    String? subtitleFallbackLocale,
  }) {
    return RuntimeLocalizationConfig(
      enableRemoteLanguagePack:
          enableRemoteLanguagePack ?? this.enableRemoteLanguagePack,
      languagePackVersion: languagePackVersion ?? this.languagePackVersion,
      languagePackUrl: languagePackUrl ?? this.languagePackUrl,
      enableContentLocalization:
          enableContentLocalization ?? this.enableContentLocalization,
      enableSubtitleByLocale:
          enableSubtitleByLocale ?? this.enableSubtitleByLocale,
      subtitleFallbackLocale:
          subtitleFallbackLocale ?? this.subtitleFallbackLocale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RuntimeLocalizationConfig &&
        other.enableRemoteLanguagePack == enableRemoteLanguagePack &&
        other.languagePackVersion == languagePackVersion &&
        other.languagePackUrl == languagePackUrl &&
        other.enableContentLocalization == enableContentLocalization &&
        other.enableSubtitleByLocale == enableSubtitleByLocale &&
        other.subtitleFallbackLocale == subtitleFallbackLocale;
  }

  @override
  int get hashCode => Object.hash(
    enableRemoteLanguagePack,
    languagePackVersion,
    languagePackUrl,
    enableContentLocalization,
    enableSubtitleByLocale,
    subtitleFallbackLocale,
  );
}
