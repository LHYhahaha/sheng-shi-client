# API Integration Readiness Plan

日期：2026-05-15

本文记录真实 API 联调前准备任务。当前 API skeleton 已覆盖主要业务域，但默认仍走
mock repository；本阶段不接真实服务端、不打开 remote 默认开关、不改 UI。

## 当前阶段

已完成：

- Network Contract Phase B：基础 header、auth policy、envelope、businessCode。
- Home / Drama API Skeleton Phase A。
- Player / Playback Source API Skeleton Phase B。
- My list / Play history API Skeleton Phase C。
- Wallet / Store / Membership / Entitlement API Skeleton Phase D。
- Auth / Profile / Session API Skeleton Phase E。
- Remote Contract Index 总索引。
- Phase F 基础设施：
  - `AppConfig` 支持 `dev` / `staging` / `prod`，并预留 `API_BASE_URL` override。
  - `ApiRequestContext` 已从统一 provider 组合 `Device-Id`、`Lang`、`Platform`、`App-Version`、`accessToken`。
  - 新增 in-memory `AuthTokenStore` skeleton，后续可替换 secure storage。
  - 新增 `AuthRefreshCoordinator` skeleton，固定 refresh in-flight 去重边界。
  - 新增 `SessionCleanupCoordinator` skeleton，作为 logout/delete/refresh failed 后的统一清理入口。

下一步进入真实 API 联调前的分域验证，仍保持 remote 默认关闭。

## Phase F 目标

把真实联调会依赖的基础设施补齐，但不真正接业务 API。

目标包括：

1. baseUrl/env 配置清晰。
2. `Device-Id`、`Lang`、`Platform`、`App-Version` 来源统一。
3. token storage 抽象准备好。
4. 401 refresh queue / 并发刷新有最小骨架或明确设计。
5. logout/delete account 后的清理入口明确。
6. remote 开关在 dev/staging/prod 下的启用策略明确。

## 任务范围

### 1. baseUrl/env

- 已完善 `dev`、`staging`、`prod` 环境配置。
- baseUrl 从统一 `AppConfig` 读取。
- 如需临时联调自定义 host，可用 `--dart-define=API_BASE_URL=https://...` override。
- 继续保持所有 feature 默认 mock。
- 文档说明不同环境如何构建和启用 remote 开关。

### 2. Request Context

统一 `ApiRequestContext` 的真实来源：

- `Device-Id`：稳定设备/安装 ID provider，当前可保留 mock fallback。
- `Lang`：已来自当前 locale / language controller，切换语言后 request context 更新。
- `Platform`：自动识别 `ios` / `android` / `web`。
- `App-Version`：当前来自可替换 provider / dart-define fallback，未来可接 package info。
- `accessToken`：来自 token store snapshot，不进 UI 层。

要求：feature 不能自己拼 header，只能通过 `ApiClient` / request context。

### 3. Token Storage Skeleton

- 已新增 `AuthTokenStore`。
- 当前使用 in-memory implementation。
- 为未来 secure storage 留实现入口。
- `accessToken` / `refreshToken` 不允许进入 presentation。

### 4. Refresh Queue Skeleton

本轮不要求完整真实 refresh，但需要准备边界：

- 已新增 `AuthRefreshCoordinator`，提供 refresh in-flight 去重边界。
- 401 捕获仍由 `ApiClient` 抛 `ApiException.unauthorized`，尚未自动 refresh/retry。
- refresh 成功后重试原请求的策略留到真实 token 接入。
- refresh 失败后应调用 `SessionCleanupCoordinator`，本轮只准备入口。

如果实现风险高，可以先以文档 + fake 测试方式落地，不影响现有 mock。

### 5. Session Cleanup

已新增统一 session cleanup 入口 `SessionCleanupCoordinator`，后续 logout/delete account 成功后调用。

需要覆盖：

- token storage：本轮已清理。
- auth session：后续真实 AuthController/session store 接入。
- feature caches：后续按 feature 注册 cleanup hook。
- playback session/window/preload：后续由 Player scope 注册 cleanup hook。

本轮不改 UI，不破坏现有 AccountPage 行为。

### 6. Remote Switch Policy

- 所有 `USE_REMOTE_XXX_API` 默认 false。
- 明确 dev/staging/prod 如何启用 remote。
- 不在页面中读取 dart-define。
- 不在本轮打开任何真实 remote 默认路径。

## 验收标准

- `ApiRequestContext` 能统一输出 `Device-Id`、`Lang`、`Platform`、`App-Version`。已测。
- 语言切换后，request context 能反映新 `Lang`。已测。
- token store 支持 read/write/clear。已测。
- auth required 请求可从 token source 取 token。已测。
- token 缺失时行为和现有设计一致，不导致 mock 业务崩溃。已测。
- 401 refresh skeleton 已有并发去重测试。
- session cleanup skeleton 已覆盖 token 清理和 hook 调用。
- 所有 remote 开关仍默认 false。已测。

## 明确不做

- 不接真实服务端。
- 不接 Google/Facebook SDK。
- 不接真实 IAP。
- 不改 UI。
- 不打开 remote 默认开关。
- 不改播放器播放逻辑。
- 不做远程语言包。
- 不做 Profile 会员/金币聚合展示收口。

## 后续顺序

Phase F 完成后，建议进入：

1. Home / Drama 真实 API 联调。
2. Player playback source 真实 API 联调。
3. My list 真实用户数据接口。
4. Entitlement / Wallet / Store / Membership 商业链路。
5. Auth / Profile 真实登录和 session 流。

继续 defer：

- package info 插件接入真实 app version。
- stable install id / device id 持久化。
- secure storage 实现。
- ApiClient 自动 refresh/retry 队列。
- logout/delete 后真实 feature cache 和 player session cleanup hooks。
- 远程语言包、内容多语言和字幕语言。
