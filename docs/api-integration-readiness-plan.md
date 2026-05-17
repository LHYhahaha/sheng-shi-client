# API Integration Readiness Plan

日期：2026-05-17

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
- Phase F Review / Integration Readiness Tightening：
  - 补充架构测试，确保 token store / refresh coordinator / cleanup coordinator 不被
    UI、页面或 feature controller 直接使用。
  - 补充 refresh failure 测试，确认失败后 in-flight 状态会释放，后续请求可重新触发 refresh。
  - 确认所有 `USE_REMOTE_XXX_API` 开关默认仍为 false。
  - 确认 Phase F 仍只提供基础设施骨架，不自动调用真实 refresh API，不打开 remote 默认路径。
- **Post-RC Track A1–A3**（2026-05-17）：
  - A1：`AuthTokenStorage` 抽象、`AuthTokenSnapshot`、`AuthTokenStore` 读写/清理；默认 in-memory。
  - A2：`ApiClient` 401 → `ApiSessionAuthHandler` 单飞 refresh + 重试一次；失败 cleanup。
  - A3：`required` 空 token → `ApiErrorCode.sessionRequired` fail-fast。
  - 测试：`auth_token_storage_test`、`api_client_session_auth_test`、`auth_runtime_boundary_test`。
  - 仍 defer：真实 refresh endpoint、`authRefreshExecutorProvider` 生产实现、secure storage 默认、A7 hooks。

- **Guest Session Bootstrap & Account Link（A1.5）**（2026-05-17）：设计文档 + `AuthSessionKind` /
  `AuthTokenSessionKind` / `GuestSessionBootstrap` skeleton；**真实 API 联调前门禁**之一。
- **Post-RC Track A4**（2026-05-17）：真实 `Device-Id`（install id 持久化）、`Lang`、`Platform`、
  `App-Version`（`package_info_plus`）；`apiRequestContextProvider` 统一注入；测试覆盖 install id /
  lang fallback / platform / version override。
- **Post-RC Track A6**（2026-05-17）：`JsonFieldParser` / `ApiMappingException`；高风险 remote DTO
  strict（Auth/Player/Drama/Entitlement/Wallet/Store/Membership/Order/MyList）；unknown enum 与
  非 map payload 不再伪装成功。

- **Home/Drama Remote Dry Run**（2026-05-17）：`drama_remote_dry_run_test` + `RecordingHttpAdapter` 验证只读
  categories/feed 链路（headers、envelope、strict DTO、provider 切换）；默认仍 mock。
- **Post-RC Track O3**（2026-05-17）：`AuthModalCoordinator` + `auth.login` AppModal；Profile 入口；
  typed `AuthLoginModalResult`；session cleanup dismiss auth modals；无自动 login on refresh failed。
  Defer：真实 login API、401→modal、各业务 `showLoginRequired` 接入。

下一步进入真实 API 联调前的分域验证（A5+、staging Home/Drama、A1.5 真实 bootstrap），仍保持 remote 默认关闭。

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

- `Device-Id`：**install id**（`installIdProvider` + `SharedPreferences`）；非硬件 ID；logout 不清；
  delete account 是否清：**待产品/合规**。
- `Lang`：`apiLangProvider` ← locale；API 支持 `en`/`es`/`pt`/`hi`，否则 `en`；远程语言包阶段可换来源。
- `Platform`：`apiPlatformProvider` → `android` / `ios` / `web`（桌面 debug 有 fallback）。
- `App-Version`：`package_info_plus` version；`APP_VERSION` dart-define override；不含 build number。
- `accessToken`：来自 token store snapshot，不进 UI 层。

要求：feature 不能自己拼 header，只能通过 `ApiClient` / request context。

### 3. Token Storage Skeleton ✅（A1）

- `AuthTokenStore` 委托 `AuthTokenStorage`（`read`/`write`/`clear`）。
- 默认 `InMemoryAuthTokenStorage`；`FlutterSecureAuthTokenStorage` 已实现，provider 未切换。
- `accessToken` / `refreshToken` / `expiresAt` 在 `AuthTokenSnapshot`；不进入 presentation。

### 4. Refresh Queue Skeleton ✅（A2，无真实 API）

- `AuthRefreshCoordinator` 单飞 in-flight refresh。
- `ApiClient` 对 `required` 请求的 HTTP 401（含 Dio 默认 validateStatus 路径）统一走
  `ApiSessionAuthHandler`；成功重试 **1 次**；refresh 请求不递归（`apiSkipAuthRefreshExtraKey`）。
- refresh 失败 / 无 refresh token → `SessionCleanupCoordinator.cleanup` 清 token + hook。
- `authRefreshExecutorProvider` 默认 stub；真实 `POST /auth/refresh` 联调时再注入。

### 4b. Required 空 token ✅（A3）

- `ApiAuthPolicy.required` 且无 access token：拦截器 fail-fast，`ApiErrorCode.sessionRequired`，不发 HTTP。

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
- 401 refresh：单飞、重试一次、并发 401 单测、refresh 失败 cleanup、refresh 不递归。已测（`api_client_session_auth_test.dart`）。
- refresh failure 后释放 in-flight。已测。
- `sessionRequired` fail-fast 不发 HTTP。已测。
- session cleanup：token clear + hook。已测。
- 所有 remote 开关仍默认 false。已测。
- token / refresh / cleanup runtime 边界未泄漏到 UI 或 feature controller。已测。

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

- delete account 是否清除 install id（合规/产品确认）。
- 远程语言包替换 `apiLangProvider` 来源。
- 真机 device model / RAM 完整 probe（`device_capability_probe`）。
- secure storage **作为生产默认**（实现已有）。
- `authRefreshExecutorProvider` 接真实 refresh API。
- A7（2026-05-17）：logout/delete/refreshFailed/sessionExpired 已接 feature cleanup hooks；Toast/Modal defer。
- Guest session 是联调门禁：生产须有 bootstrap；login 须 account link；cleanup 后不得保留正式用户 feature 态。
- 远程语言包、内容多语言和字幕语言。
