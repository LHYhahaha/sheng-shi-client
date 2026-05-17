# Drama Client

Flutter short drama client.

## Documentation

### API / 封板与契约

- [Remote Contract Index（远程契约总索引）](docs/remote-contract-index.md)
- [Mock Data & API Readiness Review（mock 与真实 API 迁移评估）](docs/mock-data-and-api-readiness-review.md)
- [App Runtime Foundation Plan（全局运行时基础）](docs/app-runtime-foundation-plan.md)
- [Player Feed Engine Refactor Plan（播放器引擎封板结论）](docs/player-feed-engine-refactor-plan.md)
- [Post-RC Roadmap & Phase Plan（封板后路线图与阶段拆分）](docs/post-rc-roadmap-and-phase-plan.md)

**当前 release 封板前提：** 所有 `USE_REMOTE_*` 开关默认 `false`；支付与权益走 mock（`grantMock*` / mock purchase delay）。若开启 remote 或真实 IAP，须先处理 401 refresh、secure token、订单验单、strict DTO 等项（见上述文档）。

### 工程与播放器

- **重点：播放器本地 HLS proxy/cache 当前不建议生产化。先读
  [Player Local HLS Proxy / Cache Decision](docs/player-local-hls-proxy-cache.md)，
  再考虑任何本地 HLS 缓存、localhost proxy、segment cache 或类似优化。**
- [项目结构与开发规范](docs/project-structure-and-conventions.md)
- [开发约束与 AI 协作规范](docs/development-guidelines.md)
- [底部导航图片资源规范](docs/bottom-navigation-assets.md)
- [Technical Architecture](docs/technical-architecture.md)
- [多语言与首页数据架构规范](docs/localization-and-home-data-architecture.md)
- [Player Experience System Architecture](docs/player-experience-architecture-plan.md)
- [Player Android Performance Policy](docs/player-android-stable-mode-plan.md)
- [Player Playback And Cache Plan](docs/player-playback-cache-plan.md)
- [Player Source And CDN Spec](docs/player-source-and-cdn-spec.md)
- [Development Schedule](docs/development-schedule.md)

## App Runtime System

全局 Runtime 是 App 启动后的统一运行时策略入口，用来集中管理设备能力、性能档位、播放器预加载配置、多语言包元数据和 feature flags。任何模块需要设备分级、运行时配置或远程配置能力，都应优先从这里扩展，避免在各 feature 内各写一套判断。

- [App Runtime System（全局运行时系统）](docs/app-runtime-system.md)

## App Runtime / Global Overlay / Modal System

全局弹窗系统是封板后的架构优化任务，用来统一登录、解锁、充值、支付确认、会员购买、确认弹窗、活动弹窗和强更弹窗等跨页面浮层。目标是避免业务弹窗被底部 tab、局部 Stack、播放器层级或安全区遮挡，并通过 typed request/result 让业务拿到明确的成功、取消、关闭或失败结果。

**当前状态（O1–O2 已落地）：**

- 阻塞式弹窗：`appModalServiceProvider` → `AppModalService`（`showConfirm` / `show` / `dismiss*`）
- 根宿主：`AppModalHost` 挂在 `DramaClientApp` builder（与 `BotToastInit` 共存）；展示使用 `appRootNavigatorKey`
- Player 解锁 / 充值 / 支付确认已迁移到全局 modal，避免 For You / bottom tab / Player Stack 层级遮挡
- 瞬态反馈仍用 `appToastProvider` → `AppToastService`，不要用 modal 替代 toast
- 测试：`RecordingAppModalService`（`test/helpers/recording_app_modal_service.dart`）记录请求并返回预设 `ConfirmResult`

```dart
final result = await ref.read(appModalServiceProvider).showConfirm(
  ConfirmModalRequest(
    requestId: ref.read(appModalControllerProvider).nextRequestId(),
    source: AppModalSource.player,
    title: 'Confirm',
    message: 'Continue?',
    confirmLabel: 'OK',
    cancelLabel: 'Cancel',
  ),
);
if (result.isConfirmed) { /* ... */ }
```

Store / Membership 等非 Player 业务弹窗仍在迁移计划中（见 O3–O4）。Player 页面内的详情、分享、倍速等局部 sheet 仍可保留局部实现；跨页面阻塞式业务弹窗应走 `AppModalService`。

- [Global Overlay / Modal System Plan（全局弹窗/浮层系统规划）](docs/global-overlay-modal-system-plan.md)
- [App Runtime Foundation Plan（全局运行时基础）](docs/app-runtime-foundation-plan.md)
- [Player Feed Engine Refactor Plan（播放器引擎封板结论）](docs/player-feed-engine-refactor-plan.md)

## Player Device Performance Policy

播放器使用同一套 Feed/Video 架构，通过 `PlayerPerformancePolicy` 按设备能力切换体验，不维护 Android/iOS 两套播放器实现。

| 档位 | 默认设备 | 可见 | 跟手 Transform | opacity 压暗 | chrome 按压渐隐 | pause scale | rich 转场 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rich` | iOS / 高性能设备 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `stable` | 普通 Android | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `ultraStable` | 低端 Android / denylist / low tier | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

关键原则：

- `stable` 要点：与 `rich` 一样用 `Transform.translate` 跟 PageView；拖动时 opacity 恒为 1.0，无压暗/渐隐/缩放等额外动画。
- `ultraStable`：拖动时切整层 `SizedBox.shrink()`，不挂 surface，优先保证低端机手势流畅。
- 真实 `Video` 只允许挂在顶层 active playback surface，不能放回 PageView item。

详细策略、denylist 和历史决策见 [Player Android Performance Policy](docs/player-android-stable-mode-plan.md)。

## Flutter Version

Use Flutter stable `3.41.9`.

```bash
fvm install 3.41.9
fvm use 3.41.9
fvm flutter doctor
```

This workspace was bootstrapped with a global Flutter `3.41.9` SDK because the local FVM download was interrupted by network instability. Once FVM has the SDK installed, use `fvm flutter ...` for all Flutter commands.
