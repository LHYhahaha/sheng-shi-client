# Remote Contract Index

日期：2026-05-17（Post-RC Track A1–A3 已落地）

本文是当前 API skeleton 的总索引，只记录远程契约、开关、分层边界和真实联调前的
defer 项。不接真实服务端，不替换 mock 默认实现，不改变 UI。

## Release 封板前提（Current）

- 所有 `USE_REMOTE_*` 默认 `false`；UI 默认 mock repository / mock payment / mock entitlement（`grantMock*`）。
- 客户端 session/network 门禁（A1–A3）已就绪：storage 抽象、401 单飞 refresh + 重试一次、
  `required` 空 token fail-fast。开启 remote 前仍须：生产 secure storage 默认、真实 refresh API、
  A7 feature cleanup hook、订单验单、strict DTO（见下文）。

## 总体约束

- 所有业务页面默认仍走 mock repository。
- remote 只通过 dart-define 或 provider override 启用。
- UI / Page / Controller 不直接 import DTO、remote data source 或 Dio。
- remote data source 只负责 API 调用和 DTO 解析。
- remote repository 只返回 domain model，不向 application/presentation 泄漏 DTO。
- 服务端 envelope 统一由 `ApiClient` 解包；业务失败通过 `ApiException.businessCode`
  透传。
- `MediaResource.network` 用于表达远程图片 URL，不再把 URL 伪装成本地 asset path。

## DTO Strict vs Display Fallback（Record Only）

封板阶段 **不收紧** mapper。真实联调前须区分：

- **Strict**：`id`、`sourceId`、`hlsUrl`、金额 raw、`accessStatus`、`orderId`、商品 id 等 — 缺失即错误。
- **Display fallback**：标题、副标题、tips、封面占位、描述等 — 可空 + UI 占位。

详见 `docs/mock-data-and-api-readiness-review.md` § DTO Strict vs Display Fallback。本轮仅记录，不改解析行为。

## 全局索引

| 模块 | Remote 开关 | 默认 | Remote repository | Remote datasource | DTO / Mapper | Endpoint skeleton | Auth policy | 测试 | 主要 defer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Network / ApiClient | 无 | 统一启用 | 不适用 | `lib/core/network/api_client.dart` | `ApiRequestContext`、`ApiPage`、`ApiException`（含 `sessionRequired`） | 所有 remote skeleton 共用 | 调用方显式传 `none/required`；`required` 无 token **不发 HTTP** | `api_client_test.dart`、`api_client_session_auth_test.dart`、`api_request_context_provider_test.dart` | 真实 device id/package info；**默认仍 in-memory token**；`authRefreshExecutorProvider` 真实 refresh；A7 cleanup hooks；网络日志脱敏 |
| Home / Drama | `USE_REMOTE_DRAMA_API`，兼容旧 `USE_REMOTE_API` | mock | `lib/features/drama/data/remote_drama_repository.dart` | `lib/features/drama/data/remote/drama_remote_data_source.dart` | `lib/features/drama/data/dto/`、`lib/features/drama/data/mapper/drama_mapper.dart` | `GET /home/categories`、`GET /home/feed` | `none`，公共首页内容假设 | `test/features/drama/drama_mapper_test.dart`、`test/features/drama/remote_drama_repository_test.dart` | 真实分页字段、内容 locale/region、推荐策略、图片 CDN 策略 |
| MediaResource | 无 | domain/shared model | 不适用 | 不适用 | `lib/shared/media/media_resource.dart` | 不适用 | 不适用 | Home/Drama/My list/Profile mapper tests | 图片缓存、占位图、错误图、CDN resize、全站图片字段迁移 |
| Player / Drama detail / For You | `USE_REMOTE_PLAYER_API` | mock | `remote_player_content_repository.dart`、`remote_player_feed_repository.dart` | `remote/player_remote_data_source.dart` | `player_content_dto.dart`、`player_episode_dto.dart`、`player_feed_item_dto.dart`、`player_feed_page_dto.dart`；`player_content_mapper.dart`、`player_feed_mapper.dart` | `GET /dramas/{dramaId}`、`GET /dramas/{dramaId}/episodes`、`GET /feed/for-you` | `none`，内容详情/feed 当前按公共内容假设；真实个性化可改 required | `test/features/player/player_remote_api_skeleton_test.dart` | 真实个性化 feed auth 策略、详情分页、内容多语言、真实 access 对象 |
| Playback Source | `USE_REMOTE_PLAYER_API` | mock | `remote_player_playback_source_repository.dart` | `remote/playback_source_remote_data_source.dart` | `playback_source_dto.dart`、`subtitle_track_dto.dart`、`preview_sprite_dto.dart`；`playback_source_mapper.dart` | `GET /episodes/{episodeId}/playback-source` | `required` | `test/features/player/player_remote_api_skeleton_test.dart` | source refresh、backup HLS fallback、subtitle UI、preview sprite UI、真实 entitlement/access、CDN signed URL 过期 |
| My list / Play history | `USE_REMOTE_MY_LIST_API` | mock | `lib/features/my_list/data/remote_my_list_repository.dart` | `lib/features/my_list/data/remote/my_list_remote_data_source.dart` | `lib/features/my_list/data/dto/`、`lib/features/my_list/data/mapper/my_list_mapper.dart` | `GET /me/favorites`、`POST /me/favorites`、`DELETE /me/favorites/{dramaId}`、`DELETE /me/favorites:batch`、`GET /me/play-history`、`DELETE /me/play-history/{historyId}` | `required` | `test/features/my_list/my_list_remote_api_skeleton_test.dart` | mutation 失败回滚、404/重复删除幂等、分页加载更多、Play history 与 PlaybackProgress 合并 |
| Wallet | `USE_REMOTE_WALLET_API` | mock | `lib/features/wallet/data/remote_wallet_repository.dart` | `lib/features/wallet/data/remote/wallet_remote_data_source.dart` | `lib/features/wallet/data/dto/`、`lib/features/wallet/data/mapper/wallet_mapper.dart` | `GET /wallet`、`GET /wallet/transactions`、`GET /wallet/consumption-records`、`GET /wallet/reward-coins`、`POST /wallet/reward-coins/{id}/claim`、`PATCH /entitlements/settings/auto-unlock` | `required` | `test/features/commerce_remote_api_skeleton_test.dart` | 钱包分页、奖励领取状态机、bonus 过期/可消费规则、订单到账后刷新 Wallet/Profile/Entitlement |
| Store / Recharge | `USE_REMOTE_STORE_API` | mock | `lib/features/store/data/remote_store_repository.dart` | `lib/features/store/data/remote/store_remote_data_source.dart` | `lib/features/store/data/dto/`、`lib/features/store/data/mapper/store_mapper.dart` | `GET /store/recharge-products`、`POST /orders` | 商品列表 `none`，创建订单 `required` | `test/features/commerce_remote_api_skeleton_test.dart` | IAP SDK、订单状态机、验单、退款/撤销、商品是否必须登录、地区/平台定价 |
| Membership | `USE_REMOTE_MEMBERSHIP_API` | mock | `lib/features/membership/data/remote_membership_repository.dart` | `lib/features/membership/data/remote/membership_remote_data_source.dart` | `lib/features/membership/data/dto/`、`lib/features/membership/data/mapper/membership_mapper.dart` | `GET /membership/products`、`GET /membership/status` | 商品列表 `none`，会员状态 `required` | `test/features/commerce_remote_api_skeleton_test.dart` | 订阅 SDK、base plan/offer 真实映射、验单、会员状态刷新、Profile 会员卡聚合 |
| Entitlement | `USE_REMOTE_ENTITLEMENT_API` | mock | `lib/features/entitlement/data/remote_entitlement_repository.dart` | `lib/features/entitlement/data/remote/entitlement_remote_data_source.dart` | `lib/features/entitlement/data/dto/`、`lib/features/entitlement/data/mapper/entitlement_mapper.dart` | `GET /entitlements`、`POST /entitlements/unlock-episode`、`PATCH /entitlements/settings/auto-unlock` | `required` | `test/features/commerce_remote_api_skeleton_test.dart`、`test/features/entitlement/entitlement_controller_test.dart` | 真实 access 接口、服务端幂等码、购买后权益刷新、跨设备同步、失败重试策略 |
| Auth / Session | `USE_REMOTE_AUTH_API` | mock | `lib/features/auth/data/remote_auth_repository.dart` | `lib/features/auth/data/remote/auth_remote_data_source.dart` | `lib/features/auth/data/dto/`、`lib/features/auth/data/mapper/auth_mapper.dart` | 同上 | login / oauth / refresh 为 `none`（refresh 带 `apiSkipAuthRefreshExtraKey`）；session / logout / delete 为 `required` | `auth_remote_api_skeleton_test.dart`、`test/core/auth/*`、`api_client_session_auth_test.dart` | Google/Facebook SDK；**secure storage 未默认**；真实 refresh executor；logout/delete 各 feature cache/player cleanup（A7） |
| Profile Summary | `USE_REMOTE_PROFILE_API` | mock | `lib/features/profile/data/remote_profile_repository.dart` | `lib/features/profile/data/remote/profile_remote_data_source.dart` | `profile_summary_dto.dart`、`profile_mapper.dart` | `GET /profile` | `required` | `test/features/auth/auth_remote_api_skeleton_test.dart` | Profile 会员卡/金币卡真实聚合、Profile 与 Wallet/Entitlement refresh 时机、头像真实图片渲染 |

## Session 身份与 Token 类型（Guest / User，2026-05-17）

产品模型：App 默认 **guest session**；登录为 **account link**。客户端 `ApiAuthPolicy.required`
= 需要任意有效 session token（guest 或正式均可），见 `docs/networking-guidelines.md`。

| 身份要求 | 说明 | 示例接口 |
| --- | --- | --- |
| **none** | 无 token | guest bootstrap（待增）、`POST /auth/login/*`、`POST /auth/refresh`（body 带 refreshToken） |
| **guestOrUser**（= 当前 `required`） | guest 或正式 access token | `GET /home/feed`、`GET /dramas/*`、游客期 entitlement（若后端允许） |
| **userRequired**（未来） | 仅正式用户 token | Wallet、My list、Entitlement 写、`POST /orders`、`GET /profile` |
| **refresh** | 专用 none + 跳过 401 refresh 队列 | `POST /auth/refresh` |

| 接口 | 当前 `ApiAuthPolicy` | 目标 token | 备注 |
| --- | --- | --- | --- |
| `POST /auth/guest/session`（待定） | none | — | bootstrap；返回 guest token |
| `POST /auth/login/device` \| oauth | none | — | 请求带 guestId + deviceId |
| `POST /auth/refresh` | none + skip refresh | guest 或 user refresh | 不与 required 空 token 冲突 |
| `GET /auth/session` | required | 任意 | 有 token 时恢复；无 token 应走 guest bootstrap |
| `GET /home/*` `GET /dramas/*` `GET /feed/*` | none（当前） | 可选 guest | 联调时可改 guestOrUser |
| `GET /episodes/*/playback-source` | required | 任意 / user（待产品） | 播放源 |
| Wallet / My list / Entitlement / orders | required | **user**（推荐） | 正式账号数据 |
| `POST /auth/logout` `DELETE /account` | required | 当前 session | 成功后 guest bootstrap |

## Auth Policy 总览

公共或本阶段按公共处理：

- `GET /home/categories`
- `GET /home/feed`
- `GET /dramas/{dramaId}`
- `GET /dramas/{dramaId}/episodes`
- `GET /feed/for-you`
- `GET /store/recharge-products`
- `GET /membership/products`
- `POST /auth/login/device`
- `POST /auth/login/oauth`
- `POST /auth/refresh`

登录后接口：

- `GET /episodes/{episodeId}/playback-source`
- My list / Play history 全部接口
- Wallet 全部接口
- `POST /orders`
- `GET /membership/status`
- Entitlement 全部接口
- `GET /auth/session`
- `POST /auth/logout`
- `DELETE /account`
- `GET /profile`

说明：`GET /auth/session` 当前定义为 token-backed session recovery，因此使用
`required`。如果服务端需要无 token 的游客 bootstrap，应新增明确的 public endpoint 或
public bootstrap 语义，不要让同一个接口同时承担两种策略。

## Provider Switch 总览

- `APP_ENV`：`dev` / `staging` / `prod`，决定 `AppConfig.current.apiBaseUrl`。
- `API_BASE_URL`：临时联调 host override，优先级高于 `APP_ENV` 的默认域名。
- `API_DEVICE_ID`：当前稳定设备 ID fallback；真实阶段应替换为持久化 install/device id。
- `APP_VERSION`：当前 app version fallback；真实阶段应替换为 package info。
- `USE_REMOTE_DRAMA_API`：Home / Drama。兼容早期 `USE_REMOTE_API`，后续联调应使用 scoped 名称。
- `USE_REMOTE_PLAYER_API`：Player detail / For You / playback source。
- `USE_REMOTE_MY_LIST_API`：My list / Play history。
- `USE_REMOTE_WALLET_API`：Wallet。
- `USE_REMOTE_STORE_API`：Store / Recharge。
- `USE_REMOTE_MEMBERSHIP_API`：Membership。
- `USE_REMOTE_ENTITLEMENT_API`：Entitlement。
- `USE_REMOTE_AUTH_API`：Auth / Session。
- `USE_REMOTE_PROFILE_API`：Profile summary。

所有开关默认 false。测试通过 provider override 或默认路径断言 mock/remote 切换；不要在页面中读取
dart-define。

## Phase F + Post-RC Track A1–A3 Runtime Context

- `AppConfig` 统一管理 dev / staging / prod baseUrl，并支持 `API_BASE_URL` 临时覆盖。
- `apiRequestContextProvider` 统一组合 header 与 `accessToken`（来自 `AuthTokenStore`）。
- `AuthTokenStorage` 抽象 + 默认 `InMemoryAuthTokenStorage`；可选 `FlutterSecureAuthTokenStorage`（未默认）。
- `ApiAuthPolicy.required` 且无 access token：`ApiClient` 本地 `sessionRequired`，**不伪造 HTTP 401**。
- `ApiSessionAuthHandler` + `AuthRefreshCoordinator`：`required` 接口 HTTP 401 时单飞 refresh，成功 **重试原请求 1 次**；失败 `SessionCleanupCoordinator` 清 token + hook。
- `POST /auth/refresh`：`none` + `apiSkipAuthRefreshExtraKey`，避免 refresh 递归。
- `authRefreshExecutorProvider` 默认 stub（未接真实服务端）。

仍 defer：安装 ID 持久化、package info、**生产默认 secure storage**、真实 refresh API、
A7 feature cleanup hooks 已接入（bootstrap）；Toast/Modal 与真实 repository reload defer。

架构测试：`auth_runtime_boundary_test.dart`；网络会话测试：`api_client_session_auth_test.dart`。
`USE_REMOTE_*` 仍默认 false。

## 分层边界检查结果

- 当前没有发现 DTO import 到 presentation/application。
- 当前没有发现 Page / Controller 直接 import remote data source。
- 当前 remote repository 输出 domain model，不直接返回 DTO。
- 已新增全局架构测试 `test/architecture/remote_contract_boundary_test.dart`，防止 remote
  contract 泄漏到 UI/controller 层。
- 已新增全局架构测试 `test/architecture/auth_runtime_boundary_test.dart`，防止 token /
  refresh / cleanup runtime 边界被 UI/controller 直接使用。
- 远程图片 URL 已通过 `MediaResource.network` 表达；Home/Drama、My list、Profile 等
  mapper 不应再把 URL 写成 asset path。

## Response Envelope / Business Code

- 所有 remote datasource 均通过 `ApiClient` 发起请求，不手写 envelope 解包。
- `code: 0` 是唯一业务成功码。
- `code != 0` 由 `ApiClient` 抛出 `ApiException` 并保留 `businessCode`。
- 已有关键模块测试覆盖：
  - Network: `test/core/network/api_client_test.dart`
  - Player: `test/features/player/player_remote_api_skeleton_test.dart`
  - My list: `test/features/my_list/my_list_remote_api_skeleton_test.dart`
  - Commerce / Entitlement: `test/features/commerce_remote_api_skeleton_test.dart`
  - Auth / Profile: `test/features/auth/auth_remote_api_skeleton_test.dart`

## 真实 API 联调前准备清单

详细 Phase F 任务记录见 `docs/api-integration-readiness-plan.md`。

P0 联调前必须确认：

- `APP_ENV` / `API_BASE_URL` 对应真实 dev/staging/prod 域名。
- ~~真实 `Device-Id` 持久化来源和 `App-Version` package info 接入。~~ **A4 Done**：install id +
  `package_info_plus`；guest bootstrap 使用同一 `Device-Id` header。
- secure storage 实现替换 in-memory `AuthTokenStore`。
- 401 自动 refresh/retry、并发刷新和 refresh 失败后的 logout 策略。
- logout / delete account 后清理 feature caches、playback sessions/window。
- 各 remote 开关在 dev/staging/prod 的启用方式。

P1 联调中应优先补齐：

- playback source refresh / backup HLS fallback。
- real entitlement/access 接口和业务码矩阵。
- Store / Membership 商品是否允许未登录浏览的最终产品策略。
- IAP SDK、server verification、order polling、退款/撤销状态。
- Wallet pagination、reward claim 状态机和订单到账后的钱包/会员/Profile refresh。
- MyList mutation 失败回滚、404/重复删除幂等处理。
- Profile 会员/金币卡由 Auth/Profile/Entitlement/Wallet 聚合派生。

P2 后续扩展：

- remote localization bundle。
- 内容多语言与字幕 tracks 的端到端 UI。
- subtitle UI / preview sprite UI。
- 图片缓存、CDN resize、poster/preview 统一资源策略。
- 本地 HLS cache/proxy 是否生产化的重新评估。
