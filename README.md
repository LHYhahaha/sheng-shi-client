# Drama Client

短剧 App Flutter 客户端。当前版本以 **mock 数据、mock 支付、mock 权益** 为默认运行模式，已完成播放器、解锁/充值/会员、全局弹窗、API 联调前基础设施等主链路封板。

## 当前封板状态

当前 RC / release 包的默认前提：

- 所有 `USE_REMOTE_*` 开关默认 `false`。
- 不连接真实后端，不连接真实 IAP。
- 支付、金币、会员、解锁均走 mock 流程。
- 真实 API 联调必须使用单独的 internal staging build，不能和 RC / release 包混用。

封板与 QA 入口：

- [Release Seal Checklist](docs/release/release-seal-checklist.md)：RC 构建规则、禁止开关、QA smoke 路径。
- [Remote API Staging Checklist](docs/api/remote-api-staging-checklist.md)：真实接口联调时如何安全打开 staging。
- [Docs Archive 2026-05 RC](docs/archive/2026-05-rc/README.md)：已完成的历史计划与过程文档。

## 文档导航

新成员建议按这个顺序阅读：

1. 本文档：了解项目状态、运行、测试、打包和公共能力入口。
2. [Docs Index](docs/README.md)：查看当前有效文档和历史归档入口。
3. [Release Seal Checklist](docs/release/release-seal-checklist.md)：了解当前 RC / release 的封板边界。
4. [AppModal Supported Modals](docs/modal/app-modal-supported-modals.md)：了解全局弹窗支持范围和使用方式。
5. [App Runtime System](docs/runtime/app-runtime-system.md)：了解设备分级、播放器策略和运行时配置。
6. [Remote Contract Index](docs/api/remote-contract-index.md)：了解未来真实 API 的模块开关和接口契约。
7. [Project Structure And Conventions](docs/engineering/project-structure-and-conventions.md)：了解目录和分层规范。

## 环境要求

Flutter:

```bash
flutter --version
```

项目使用 Flutter stable `3.41.9`。如果使用 FVM：

```bash
fvm install 3.41.9
fvm use 3.41.9
fvm flutter doctor
```

依赖安装：

```bash
flutter pub get
```

## 本地运行

默认 mock 模式运行：

```bash
flutter run
```

运行测试：

```bash
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Android release 包：

```bash
flutter build apk --release
flutter install -d <deviceId> --release
```

可选真机冒烟：

```bash
flutter test integration_test/app_smoke_test.dart -d <deviceId>
```

注意：运行 `flutter test integration_test/...` 会安装 debug 测试包。若要继续手测 release，需要最后重新执行 `flutter install --release`。

## Release 构建安全规则

RC / release 包禁止携带任何真实接口开关：

```bash
# 正确：mock RC / release
flutter build apk --release

# 禁止：不要把这种包当 RC / release
flutter build apk --release \
  --dart-define=API_BASE_URL=https://example.backend \
  --dart-define=USE_REMOTE_DRAMA_API=true
```

RC / release 禁止项：

- `USE_REMOTE_API=true`
- `USE_REMOTE_DRAMA_API=true`
- `USE_REMOTE_PLAYER_API=true`
- `USE_REMOTE_MY_LIST_API=true`
- `USE_REMOTE_PROFILE_API=true`
- `USE_REMOTE_AUTH_API=true`
- `USE_REMOTE_ENTITLEMENT_API=true`
- `USE_REMOTE_WALLET_API=true`
- `USE_REMOTE_STORE_API=true`
- `USE_REMOTE_MEMBERSHIP_API=true`
- 真实 `API_BASE_URL`
- `PLAYER_HLS_LOCAL_PROXY_SPIKE=true`

真实接口联调只允许使用 internal staging build，第一阶段只建议打开 `USE_REMOTE_DRAMA_API=true`。完整规则见 [Remote API Staging Checklist](docs/api/remote-api-staging-checklist.md)。

## 目录结构

```text
lib/
  app/                 App shell、router、root navigator
  bootstrap/           App 启动注册入口，如 modal registry、session cleanup hooks
  core/                网络、auth token、runtime、modal、toast 等跨 feature 基础设施
  features/            feature-first 业务模块
  l10n/                本地化入口
  shared/              theme、media、通用 UI / domain 小工具
test/
  architecture/        架构边界测试
  core/                core 层单元测试
  features/            feature 测试
integration_test/      真机 smoke 测试
docs/                  项目规范、架构、联调、封板文档
```

详细规范见 [Project Structure And Conventions](docs/engineering/project-structure-and-conventions.md)。

## 公共能力

### App Runtime

Runtime 是 App 启动后的统一运行时策略入口，负责设备能力、性能档位、播放器预加载、多语言包元数据和 feature flags。

常用入口：

- `appRuntimeConfigProvider`
- `deviceCapabilityProvider`
- `playerPerformancePolicyProvider`
- `playerPreloadConfigProvider`

原则：

- 设备分级、性能策略、预加载数量不要散落在 feature 内。
- 远程配置未来应合并进 `AppRuntimeConfig`，再由各 feature 派生自己的配置。
- 当前远程配置未接真实服务端。

文档：[App Runtime System](docs/runtime/app-runtime-system.md)。

### Remote API Switches

远程接口开关统一由 `RemoteApiSwitches` 和 `RemoteApiReadinessGuard` 描述。

当前所有 remote 默认关闭：

```text
USE_REMOTE_DRAMA_API=false
USE_REMOTE_PLAYER_API=false
USE_REMOTE_MY_LIST_API=false
USE_REMOTE_PROFILE_API=false
USE_REMOTE_AUTH_API=false
USE_REMOTE_ENTITLEMENT_API=false
USE_REMOTE_WALLET_API=false
USE_REMOTE_STORE_API=false
USE_REMOTE_MEMBERSHIP_API=false
```

联调示例，仅 internal staging 使用：

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://<staging-host> \
  --dart-define=USE_REMOTE_DRAMA_API=true
```

原则：

- 生产/RC 不允许误开 remote。
- 高风险模块（auth、entitlement、wallet、store、membership）在真实验单和后端契约完成前不得开启。
- DTO 使用 strict parser，缺关键字段应 fail fast，不静默伪装成成功。

文档：

- [Remote Contract Index](docs/api/remote-contract-index.md)
- [Remote API Staging Checklist](docs/api/remote-api-staging-checklist.md)
- [Mock Data And API Readiness Review](docs/api/mock-data-and-api-readiness-review.md)

### AppModal 全局弹窗

全局阻塞式业务弹窗统一走 `AppModalService`，避免被底部 tab、局部 Stack、播放器层级或 safe area 遮挡。

已迁移到 AppModal 的业务：

- Player 金币解锁小弹窗、充值大抽屉
- Auth 登录、login required、session expired 登录入口
- Store 购买确认
- Membership 购买确认

当前特殊项：

- Player `Payment Method`（O2.1 Done）已迁入 AppModal：`player.payment_method` channel + `stackOnCurrent` 叠于充值大抽屉；`PaymentModalResult` typed result；`dismissForSource(player)` 可一并关闭。

仍保留本地弹窗的局部 UI：

- Player 详情、分享、倍速
- Account delete 确认

使用通用确认弹窗：

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

if (result.isConfirmed) {
  // Continue.
}
```

业务弹窗如果需要自定义 UI，应通过 feature payload/result + presenter registry 接入，不能让 `core/modal` 反向依赖 feature。

文档：[Global Overlay / Modal System Plan](docs/modal/global-overlay-modal-system-plan.md)。

已支持弹窗清单、用途和接入方式见 [AppModal Supported Modals](docs/modal/app-modal-supported-modals.md)。

### Toast

瞬态反馈使用 `AppToastService`，不要用 modal 替代 toast。

```dart
ref.read(appToastProvider).success('Unlock successful');
ref.read(appToastProvider).error('Something went wrong');
ref.read(appToastProvider).info('Coming soon');
```

约束：

- feature 层不要直接 import `bot_toast`。
- 第三方 toast 只在 `core/toast` 和 app shell 内部封装。

### Auth / Session Cleanup

当前支持：

- token storage 抽象
- 401 refresh 单飞队列
- required auth 空 token fail-fast
- guest session / account link 设计
- logout / deleteAccount / refreshFailed / sessionExpired 的 cleanup hooks

cleanup 会执行：

1. 清 token
2. 关闭阻塞式业务 modal
3. 重置 Auth / Entitlement / Wallet / Profile / MyList / Store / Membership
4. 停止并释放播放器 session
5. 触发 guest bootstrap stub

真实 guest bootstrap HTTP、OAuth、secure storage 默认启用仍在后续阶段。

文档：

- [API Integration Readiness Plan](docs/api/api-integration-readiness-plan.md)
- [Networking Guidelines](docs/api/networking-guidelines.md)
- [API Integration Plan](docs/api/api-integration-plan.md)

### Player Performance Policy

播放器使用同一套 Feed/Video 架构，通过 `PlayerPerformancePolicy` 按设备能力切换体验。

| 档位 | 默认设备 | 拖动时 Video 可见 | 跟手 Transform | opacity 压暗 | chrome 按压渐隐 | pause scale | rich 转场 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `rich` | iOS / 高性能设备 | 是 | 是 | 是 | 是 | 是 | 是 |
| `stable` | 普通 Android | 是 | 是 | 否 | 否 | 否 | 否 |
| `ultraStable` | 低端 Android / denylist | 否 | 否 | 否 | 否 | 否 | 否 |

原则：

- 真实 `Video` 只能在顶层 active playback surface。
- PageView item 只承载轻量 shell。
- locked / unavailable / null source 不 open、不 prepare、不 preload 未授权 source。
- 不生产化 HLS local proxy/cache。

文档：

- [Player Android Performance Policy](docs/player/player-android-stable-mode-plan.md)
- [Player Feed Engine Refactor Plan](docs/player/player-feed-engine-refactor-plan.md)
- [Player Source And CDN Spec](docs/player/player-source-and-cdn-spec.md)
- [Player Local HLS Proxy / Cache Decision](docs/player/player-local-hls-proxy-cache.md)

### Commerce / Entitlement

当前封板版本使用 mock payment 和 mock entitlement：

- Store 金币 / VIP mock purchase 会写入 `EntitlementController`
- Player 解锁、充值、会员购买走 mock flow
- Wallet auto unlock 与 Player coin unlock sheet 共用 entitlement 状态
- `bonusBalance` 当前不参与扣费，真实规则等后端确认

真实支付阶段必须补齐：

- IAP SDK
- 订单创建与验单
- 服务端权益刷新
- wallet / store / membership remote repository
- 禁止生产路径调用 mock grant

文档：

- [Entitlement Commerce Player Regression](docs/release/entitlement-commerce-player-regression.md)
- [Mock Data And API Readiness Review](docs/api/mock-data-and-api-readiness-review.md)

### Localization

当前本地化仍以本地包为主。后续规划包括：

- 固定语言包远程版本检查
- 内容多语言
- 字幕按客户端语言选择
- 远程语言包下载与本地缓存

文档：[Localization And Home Data Architecture](docs/localization/localization-and-home-data-architecture.md)。

## 常用文档入口

封板 / QA：

- [Release Seal Checklist](docs/release/release-seal-checklist.md)
- [Entitlement Commerce Player Regression](docs/release/entitlement-commerce-player-regression.md)

API / 联调：

- [Remote API Staging Checklist](docs/api/remote-api-staging-checklist.md)
- [Remote Contract Index](docs/api/remote-contract-index.md)
- [API Integration Readiness Plan](docs/api/api-integration-readiness-plan.md)
- [Networking Guidelines](docs/api/networking-guidelines.md)

播放器：

- [Player Experience System Architecture](docs/player/player-experience-architecture-plan.md)
- [Player Feed Engine Refactor Plan](docs/player/player-feed-engine-refactor-plan.md)
- [Player Android Performance Policy](docs/player/player-android-stable-mode-plan.md)
- [Player Source And CDN Spec](docs/player/player-source-and-cdn-spec.md)

工程规范：

- [Project Structure And Conventions](docs/engineering/project-structure-and-conventions.md)
- [Technical Architecture](docs/engineering/technical-architecture.md)
- [Bottom Navigation Assets](docs/engineering/bottom-navigation-assets.md)
- [AppModal Supported Modals](docs/modal/app-modal-supported-modals.md)

历史归档：

- [2026-05 RC Historical Archive](docs/archive/2026-05-rc/README.md)

## 后续明确 defer

以下内容不属于当前 mock RC：

- A8.1 effective remote switches 接入 provider
- secure storage 默认启用
- guest bootstrap HTTP
- real OAuth
- real IAP / order verification
- remote entitlement / wallet / store / membership
- Profile DTO strict
- PlayerPlaybackController 拆分
- Modal Ops（活动、强更、风控弹窗）

新增上述能力前，请先更新对应文档和测试矩阵。
