# App Runtime System（全局运行时系统）

> **Document status: Current（封板说明）** — 本文描述当前客户端已经落地的全局
> runtime 基础设施、配置合并优先级、设备分级、播放器消费链路，以及后续远程配置/
> 多语言扩展边界。历史阶段计划见
> [App Runtime Foundation Plan](app-runtime-foundation-plan.md)。

## 1. 目标

全局 runtime 是 App 启动后所有“运行时策略”的统一入口。它不是某个 feature 的私有配置，也不是业务状态仓库。

它负责：

- 统一描述本机设备能力，例如平台、型号、厂商、内存、CPU 与性能档位。
- 统一合并本地默认值、设备规则、远程配置和测试/debug override。
- 统一承载播放器预加载、性能档位、多语言包元数据、字幕跟随、灰度开关等运行时配置。
- 避免 Home / Player / Store / Wallet / Localization 等模块各自写一套设备判断或 remote config 入口。
- 保证远程配置失败、缺字段、解析失败时 App 仍能启动，并回退到本地安全默认值。

它不负责：

- 不保存用户登录 token、钱包余额、会员权益、订单、播放进度等业务真相。
- 不直接拉取剧集、商品、钱包、会员等业务接口。
- 不直接控制播放器 play / pause / seek。
- 不替代 Flutter `AppLocalizations`，当前只预留远程语言包元数据。

## 2. 当前文件结构

```text
lib/core/runtime/
  app_runtime_config.dart              # 全局配置根对象
  app_runtime_config_provider.dart     # 默认/设备/远程/override 合并入口
  device_capability.dart               # 设备能力快照与性能档位
  device_capability_provider.dart      # 设备能力 provider 与测试 override
  device_capability_probe.dart         # 启动探针预留点（Phase B 接真实硬件读取）
  device_performance_tier_rules.dart   # 本地设备分级规则与低端机 denylist
  runtime_player_config.dart           # 播放器预加载、日志、性能档位配置
  runtime_localization_config.dart     # 远程语言包、内容本地化、字幕策略元数据
  runtime_feature_flag_config.dart     # 全局 feature flags
  runtime_performance_mode.dart        # feature-neutral 的性能档位
```

播放器不直接让 `core/runtime` import player feature。映射放在 player application 层：

```text
RuntimePerformanceMode
  -> PlayerPerformanceMode
  -> PlayerPerformancePolicy
  -> PlayerPreloadConfig
```

这样 `core/runtime` 保持 feature-neutral，未来 Home、Localization、Commerce 也能复用。

## 3. 配置根对象

当前根对象是 `AppRuntimeConfig`：

```text
AppRuntimeConfig
  ├─ player: RuntimePlayerConfig
  ├─ localization: RuntimeLocalizationConfig
  └─ featureFlags: RuntimeFeatureFlagConfig
```

### 3.1 RuntimePlayerConfig

用于播放器运行时策略，包含：

| 字段 | 用途 | 当前默认 |
| --- | --- | --- |
| `performanceModeOverride` | 远程/实验覆盖性能档位 | `null` |
| `homeStartupHlsPreloadCount` | 首页首卡 HLS HTTP 预热数量 | `1` |
| `singleDramaForwardHlsPreloadCount` | 单剧向后 HLS 预热数量 | `1` |
| `singleDramaBackwardHlsPreloadCount` | 单剧向前 HLS 预热数量 | `1` |
| `forYouForwardHlsPreloadCount` | For You 向后 HLS 预热数量 | `1` |
| `forYouBackwardHlsPreloadCount` | For You 向前 HLS 预热数量 | `1` |
| `hlsPlaylistTimeout` | HLS playlist / segment 预取超时 | `4s` |
| `hlsMaxPreloadBytes` | 单条 HLS 预热字节上限 | `2 MiB` |
| `enablePlaybackTimingLogs` | 播放链路 timing 日志 | `false` |
| `enableRebuildLogs` | Player rebuild / overlay 诊断日志 | `false` |
| `autoImmersiveDelay` | 单剧播放中无操作后自动隐藏 chrome 进入沉浸的等待时长（仅 UI） | `3s` |
| `enableAutoImmersiveForSingleDrama` | 是否在单剧播放器启用自动沉浸 chrome | `true` |

注意：

- `autoImmersiveDelay` / `enableAutoImmersiveForSingleDrama` 只作用于 `PlayerUiController` 的 chrome 展示，**不**改变 `PlayerPlaybackController` 播放真相，**不**用于 For You（For You 在 UI 层固定关闭自动沉浸）；测试可通过 `playerChromeAutoImmersiveConfigOverrideProvider` 覆盖延迟。
- 这里的 HLS 预热只做 HTTP playlist/segment 预热，不持有播放器实例。
- prepared / retained media session 数量不由 remote runtime 随意扩大，仍由 `PlayerPerformancePolicy` 控制。
- 低端机规则会把 HLS 预热数量收紧到 `0`。

### 3.2 RuntimeLocalizationConfig

用于多语言相关元数据，当前只建模，不下载、不替换 l10n：

| 字段 | 用途 |
| --- | --- |
| `enableRemoteLanguagePack` | 是否启用远程 UI 语言包下载 |
| `languagePackVersion` | 服务端下发的语言包版本 |
| `languagePackUrl` | 语言包 JSON 地址 |
| `enableContentLocalization` | 内容接口是否按语言返回剧集标题/简介等 |
| `enableSubtitleByLocale` | 播放器是否按客户端语言自动选择字幕 |
| `subtitleFallbackLocale` | 字幕匹配失败后的回退语言 |

设计边界：

- 固定 UI 文案与内容多语言是两条链路。
- 固定 UI 文案当前仍走 Flutter codegen `AppLocalizations`。
- 内容本地化后续通过业务接口 `Lang` header / 内容 API 返回。
- 字幕跟随属于播放器展示策略，未来通过播放源接口的 subtitle tracks 实现。

### 3.3 RuntimeFeatureFlagConfig

用于全局灰度 / 实验开关：

```dart
RuntimeFeatureFlagConfig(flags: {'some_key': true})
```

规则：

- 缺失 key 默认 `false`。
- 只能放运行时功能开关，不能放 token、用户 id、订单、权益等敏感/业务真相。
- HLS local proxy/cache 不允许通过 runtime feature flag 开启；它只保留为 `PLAYER_HLS_LOCAL_PROXY_SPIKE` 诊断开关。

当前 key 示例：

| Key | 说明 |
| --- | --- |
| `remote_localization` | 远程 UI 语言包 |
| `subtitle_by_locale` | 按 locale 自动选字幕 |
| `new_unlock_sheet` | 解锁 sheet 实验 UI |
| `api_remote_drama` | 剧集列表远程 API 灰度 |

## 4. 合并优先级

`appRuntimeConfigProvider` 是全局 runtime 配置唯一合并入口。

优先级从低到高：

```text
AppRuntimeConfig.defaults
  -> deviceCapabilityProvider 设备规则
  -> appRuntimeRemoteConfigProvider 远程配置片段
  -> appRuntimeConfigOverrideProvider 测试/debug 覆盖
```

当前代码行为：

1. 先读取 `AppRuntimeConfig.defaults`。
2. 根据 `DeviceCapability` 应用设备规则，例如低端机收紧 HLS 预热。
3. 如果未来远程配置不为 null，则按分组 merge；缺字段保留当前值。
4. 远程 merge 后再次应用设备规则，避免低端机被远程误放大。
5. 测试/debug override 优先级最高。

远程配置失败必须表现为 `null`，不能阻塞启动。

## 5. 设备能力与性能档位

### 5.1 DeviceCapability

`DeviceCapability` 是启动时的一份设备快照：

| 字段 | 说明 |
| --- | --- |
| `platform` | Android / iOS / macOS / web 等 |
| `osVersion` | 系统版本，无法读取时 `unknown` |
| `deviceModel` | 设备型号，无法读取时平台占位 |
| `manufacturer` | 厂商 |
| `physicalMemoryMb` | 物理内存 MB，当前可为 null |
| `processorCount` | CPU 逻辑核心数，当前可为 null |
| `performanceTier` | `low` / `standard` / `high` |

### 5.2 本地分级规则

规则入口是 `resolveDevicePerformanceTier`。

当前规则：

| 条件 | 档位 |
| --- | --- |
| iOS / macOS | `high` |
| Android + denylist 命中 | `low` |
| Android + 已知 RAM ≤ 3072 MB | `low` |
| Android + RAM 约 4GB | `standard` |
| Android + 未知型号 / `android-generic` | `standard` |
| Android + `SM-A146` 等非 A14 denylist 型号 | `standard` |

当前 denylist 保守覆盖：

- Samsung `SM-A145*`
- Samsung `SM-A14*` 字母后缀变体
- `Galaxy A14`

注意：

- denylist 不是完整设备库，只收录已验证风险机型。
- Android 不自动升到 `high`，高内存 Android 仍默认 `standard`，避免误开 rich。
- iOS 默认 `high`，播放器映射到 `rich`。

## 6. 播放器如何消费 Runtime

播放器消费链路如下：

```text
DeviceCapability.performanceTier
  -> RuntimePerformanceMode
  -> PlayerPerformanceMode
  -> PlayerPerformancePolicy
  -> PlayerPreloadConfig
```

### 6.1 PlayerPerformancePolicy

当前封板策略：

| 档位 | 默认设备 | 可见 | 跟手 Transform | opacity 压暗 | chrome 按压渐隐 | pause scale | rich 转场 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rich` | iOS / 高性能设备 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stable` | 普通 Android | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ultraStable` | 低端 Android / denylist / low tier | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

关键结论：

- `stable` 也要让 Video 跟随 PageView，否则视频不动、文字滑动会造成割裂。
- `stable` 只保留必要的 `Transform.translate`，不做压暗、渐隐、缩放等额外动画。
- `ultraStable` 才在拖动时隐藏 Video surface，优先保证低端机手势流畅。
- 真实 `Video` 只允许挂在顶层 active playback surface，不能放回 PageView item。

### 6.2 PlayerPreloadConfig

`playerPreloadConfigProvider` 是播放器预加载最终入口。

来源：

1. 基础值来自 `PlayerPerformancePolicy.toPreloadConfig()`。
2. 再合并 `AppRuntimeConfig.player` 的 HLS 数量 / 超时 / 字节配置。
3. `ultraStable` 下 remote/runtime 不得把 HLS 与 session 策略撑大。
4. 完整 `playerPerformancePolicyOverrideProvider` 仅用于测试/debug，可显式覆盖。

## 7. Override 与测试入口

常用 override：

| Provider | 用途 |
| --- | --- |
| `deviceCapabilityOverrideProvider` | 覆盖完整设备能力快照 |
| `devicePerformanceTierOverrideProvider` | 只覆盖性能档位 |
| `appRuntimeConfigOverrideProvider` | 覆盖完整 runtime config |
| `playerPerformanceModeOverrideProvider` | 覆盖播放器档位 |
| `playerPerformancePolicyOverrideProvider` | 覆盖完整播放器策略 |

示例：

```dart
devicePerformanceTierOverrideProvider.overrideWithValue(
  DevicePerformanceTier.low,
)
```

这会走：

```text
low -> RuntimePerformanceMode.ultraStable -> PlayerPerformanceMode.ultraStable
```

用于低端机策略测试。

## 8. 后续扩展阶段

### Phase B：真实设备探针

目标：

- 接入 `device_info_plus` 或 platform channel。
- 读取 Android model / manufacturer / SDK。
- 尝试读取物理内存 / CPU 核心数。
- 继续调用现有 `resolveDevicePerformanceTier`，不要在 feature 内重写规则。

### Phase C：App Version / Device Id 统一

目标：

- `apiAppVersionProvider` 接 `package_info_plus`。
- `apiDeviceIdProvider` 与 install id / 设备标识统一。
- 保持 API header 与 runtime device layer 边界清晰。

### Phase D：Remote Config Repository

目标：

- 新增 `AppRuntimeRepository`。
- 启动后拉取远程 runtime JSON。
- 本地缓存上一次成功配置。
- 网络失败 / 解析失败 / 签名失败时回退本地默认或缓存。

要求：

- 不能阻塞 App 首屏。
- 远程配置必须 typed mapper，不允许 UI 直接读 raw JSON。
- 远程缺字段必须保留本地安全默认。

### Phase E：远程语言包

目标：

- 根据 `RuntimeLocalizationConfig.languagePackVersion` 对比本地版本。
- 有更新时下载语言包 JSON。
- 校验版本、签名、schema。
- 保存本地并切换 UI 文案读取链路。

注意：

- 固定 UI 语言包、内容本地化、字幕轨是三套能力，不能混在一个字段里。
- 内容接口仍通过 `Lang` header / 真实 API 返回本地化剧集数据。

## 9. 禁止事项

- 不允许 feature 模块自己读取设备型号并决定性能档位。
- 不允许 Player / Home / Store 等 feature 直接拉 runtime remote config。
- 不允许把 remote config raw JSON 传给 UI。
- 不允许用 runtime feature flag 发放金币、会员、权益。
- 不允许通过 runtime flag 生产化 HLS local proxy/cache。
- 不允许远程配置绕过低端机保守规则，盲目扩大 media session window。
- 不允许远程配置失败阻塞 App 启动。

## 10. 封板结论

当前 runtime 已经满足封板版本需要：

- 有统一配置根对象。
- 有播放器、多语言、feature flag 三个分组。
- 有设备能力与低端机本地分级规则。
- 有明确合并优先级和测试 override。
- 播放器性能策略与预加载策略已经从 runtime 链路消费。
- 真实远程配置、设备探针、多语言包下载仍在后续阶段，不阻塞当前版本。

