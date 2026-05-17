# Mock Data And API Readiness Review

日期：2026-05-15

本文只评估当前 mock 数据、domain model、repository 边界到真实 API 的可迁移性，不接真实接口、不改 UI、不调整业务逻辑。结论基于当前 feature-first 结构、`docs/api-integration-plan.md`、`docs/player-source-and-cdn-spec.md`、`docs/entitlement-unlock-flow-plan.md` 和播放器资源调度相关文档。

## Release 封板前提（Current）

- 封板默认：`USE_REMOTE_*=false`，mock payment / mock entitlement（含 Store/Player 充值成功后的 `grantMock*`）。
- 开启 remote 或真实支付前：须完成 401 refresh、订单验单、strict DTO、auth 端点矩阵等（见 `docs/remote-contract-index.md`）。

## 总体结论

当前项目的 mock 到 API 迁移基础是健康的：大多数页面已经通过 domain model + repository + controller 访问数据，UI 没有直接依赖 Dio/HTTP，也没有在 Page 中散落大量 mock JSON。播放器、权益、商店、会员、钱包几个复杂模块已经形成比较清晰的“展示状态”和“业务真相”边界。

真正接 API 前不建议直接替换 mock repository。更稳的路径是先补 `remote datasource -> DTO -> mapper -> repository implementation` 这一层，让 presentation/application 继续只感知 domain model。这样可以避免接口字段、价格金额、签名播放源、支付订单状态直接泄漏到 UI。

当前没有阻塞真实接口接入的 P0，但有若干 P1 数据契约需要在 Phase A/B 前收口，尤其是图片/视频资源 URL 归一化、支付价格 raw/display 拆分、Profile 聚合来源、Wallet 记录细分、播放源 sourceId/expiresAt/字幕/preview sprite 的真实字段映射。

## DTO Strict vs Display Fallback ✅（A6，2026-05-17）

**已落地**（remote DTO + 高风险 mapper；mock repository 未改）：

| 类型 | 原则 | 示例字段 |
| --- | --- | --- |
| **Strict contract** | 缺失 / 类型错误 → `ApiMappingException` | `id`、`sourceId`、`hlsUrl`、`expiresAt`、`token`、`unlockType`、`priceMicros`、`orderId`/`status`、`enabled`、`entitlement type`/`coinBalance` |
| **Display fallback** | 允许空值 + mapper/UI 占位 | `title`、`subtitle`、`coverUrl`、`description`、`viewCountLabel` |

工具：`lib/core/network/json_field_parser.dart`。已加固模块见 `docs/remote-contract-index.md`。

**仍 defer**：Profile DTO、FavoriteMutation、Wallet 子记录 status、全站 DTO 迁移。

## 模块现状与 API 对接建议

| 模块 | 当前数据来源 | 当前 readiness | 未来 repository / endpoint 建议 | 主要注意点 |
| --- | --- | --- | --- | --- |
| Home / Drama | `DramaRepository` + `MockDramaRepository` | 边界清晰 | `GET /home/categories`、`GET /home/feed` | Home 不携带播放源是正确方向，封面 asset 需要映射为 remote image |
| Player / Playback | `PlayerFeedRepository`、`PlayerContentRepository`、`PlayerPlaybackSourceRepository` | 主链路成熟 | `GET /dramas/{id}`、`GET /dramas/{id}/episodes`、`GET /episodes/{id}/playback-source` | source resolve、entitlement、HLS 策略必须保持独立 |
| Entitlement | `EntitlementRepository` + `MockEntitlementRepository` | MVP 规则完整 | `GET /entitlements`、`POST /entitlements/unlock` | 真实权益以后端为准，客户端 purchase success 不能直接发放永久权益 |
| Store / Recharge | `StoreRepository` + `MockStoreRepository` | UI/状态可迁移 | `GET /store/recharge-products`、`POST /orders` | 价格展示 label 与支付 raw amount/platform product id 需要拆开 |
| Membership | `MembershipRepository` + `MockMembershipRepository` | UI/状态可迁移 | `GET /membership/products`、`GET /membership/status` | 商品列表和会员状态建议拆接口 |
| Wallet | `WalletRepository` + `WalletController` + shared entitlement | MVP 可用 | `GET /wallet`、`GET /wallet/transactions`、`PATCH /wallet/settings` | 余额/auto unlock 已向 entitlement 收敛，流水类型后续可进一步细分 DTO |
| My list / Play history | `MyListRepository` + `MockMyListRepository` | 列表交互可迁移 | `GET /me/favorites`、`GET /me/play-history`、`DELETE /me/favorites/{id}` | 收藏、追剧、播放历史真实 mutation 需要拆清 |
| Auth / Profile | `AuthRepository`、`ProfileController` mock | Auth 边界清晰，Profile 仍是摘要 mock | `POST /auth/*`、`GET /profile` | Profile 展示应由 Auth/Profile/Entitlement/Wallet 聚合 |
| Localization | 手写 `AppLocalizations` | 固定文案稳定 | `GET /localization/bundles/{locale}` | 固定语言包、内容多语言、字幕语言必须分开 |

## Home / Drama

当前模型：

- `DramaCategory`：`id`、`title`。
- `Drama`：`id`、`title`、`coverAssetPath`、`viewCountLabel`、`episodeCount`、`categoryId`、`tags`、`coverAspectRatio`、`isExclusive`。
- `DramaFeedPage`：`items`、`nextPageToken`。
- `HomeFeedState`：分类、当前 tab、列表、分页 token、initial/loadingMore/error 状态。

当前设计符合真实首页 feed 的基本需求：分类 id 稳定，分页游标独立，Home 不携带播放源，点击后再进入 Player feed/source resolve。这个边界应保留。

真实 API 建议：

- `GET /home/categories?locale=...`
- `GET /home/feed?categoryId=popular&pageToken=...&pageSize=...&locale=...`

建议 response 字段：

- `categoryId`、`title`、`items`、`nextPageToken`
- item: `dramaId`、`title`、`localizedTitle`、`coverUrl`、`coverAspectRatio`、`viewCount`、`viewCountLabel`、`episodeCount`、`tags`、`badges`、`rankingScore`

需要调整：

- `coverAssetPath` 目前是本地 asset 字段。真实 API 阶段建议在 mapper 中归一化为 `coverResource` 或至少区分 `coverAssetPath/coverUrl`，避免 UI 到处判断 asset/network。
- `viewCountLabel` 是展示字段，真实接口最好同时返回 raw `viewCount` 和 display `viewCountLabel`。客户端不应解析 label 排序。
- `Drama.id` mock 中会拼接序号形成 `found-you-0` 这类值。真实接口必须使用稳定 `dramaId`，分页重复展示不应改变业务 id。

## Player / For You / Playback

当前模型：

- `PlayerContent`：剧详情、播放页标题、简介、背景图、poster、episodes、recommendations。
- `PlayerEpisode`：`id`、`number`、`isLocked`、`unlockType`、`requiredCoins`、`videoUrl/videoAssetPath`、`videoAspectRatio`、`isAvailable`。
- `PlayerFeedItem`：`id`、`mode`、`content`、`episode`。
- `PlaybackSource`：`itemId`、`remoteUrl`、`playableSource`、`cacheKey`、`expiresAt`、`codecHint`、`status`。
- `PlayerPlaybackSourceRepository`：统一 resolve/preload source。

当前播放器数据边界整体成熟：Player feed 负责“展示哪一集”，Playback source repository 负责“拿到可播放源”，Entitlement 负责“是否能播”。这三者不要合并。

真实 API 建议：

- `GET /dramas/{dramaId}?locale=...`
- `GET /dramas/{dramaId}/episodes?pageToken=...`
- `GET /feed/for-you?pageToken=...&locale=...`
- `GET /episodes/{episodeId}/playback-source?quality=auto&subtitleLanguage=...`
- `POST /playback/progress`
- `GET /playback/progress?episodeId=...`

播放源 response 必须对齐 `docs/player-source-and-cdn-spec.md`：

- `episodeId`
- `sourceId`
- `hlsUrl`
- `backupHlsUrls`
- `expiresAt`
- `durationMs`
- `width`
- `height`
- `aspectRatio`
- `codec`
- `bitrateLadder`
- `posterUrl`
- `previewSpriteUrl`
- `previewVttUrl`
- `subtitleTracks`
- `cachePolicy`
- `preloadPolicy`
- `access`

需要调整：

- `PlayerEpisode.videoUrl` 当前是 source hint。真实阶段建议不要让内容详情接口直接返回最终可播放 URL，或即使返回也只当 hint；最终 HLS URL 应从 playback-source 接口 resolve。
- `isLocked/unlockType/requiredCoins` 适合 mock，但真实接口建议由 `access` 对象映射：`accessStatus`、`unlockType`、`priceCoins`、`isMemberOnly`、`isUnavailable`、`reasonCode`。
- `PlayerFeedItem.id` 当前承担 session/window/timing 的稳定 key。真实阶段应保证由 `dramaId + episodeId + feedMode/sourceId?` 稳定生成，不要用列表 index。
- `PlaybackSource.cacheKey` 必须包含 `sourceId/contentLanguage/subtitleLanguage/quality/accessLevel` 等维度。不能只按 URL，签名 URL 轮换会造成错配。
- subtitles、preview sprite、duration、aspect ratio 的未来位置应在 `PlaybackSource` 或播放源 DTO mapper 中明确，不要继续散落到 episode mock。

## Entitlement

当前模型：

- `EpisodeUnlockType`：`free`、`membership`、`coins`。
- `EpisodeAccessDecisionType`：`allowPlay`、`goMembership`、`showCoinUnlockDialog`、`showRechargeDialog`、`autoUnlockAndPlay`、`waitUnlock`。
- `UserEntitlementState`：游客/会员/金币/auto unlock/已解锁/pending/in-flight/error。
- `EntitlementRepository`：fetch state、grant mock coins/membership、coin unlock、auto unlock 设置。

E1-E3 后，Player、Store、Membership、Wallet 已开始共享 entitlement 状态，这是正确方向。

真实 API 建议：

- `GET /entitlements`
- `POST /entitlements/unlock-episode`
- `PATCH /entitlements/settings/auto-unlock`
- `GET /membership/status`
- `GET /wallet/balance`

需要调整：

- `grantMockCoins/grantMockMembership` 是 mock 专用能力。真实阶段购买成功后必须调用订单/验单接口，再刷新 `GET /entitlements` 和钱包/会员状态。
- `unlockedEpisodeIds` mock 阶段只按 episodeId 存储。真实阶段至少要考虑账号、dramaId、episodeId、sourceId、accessLevel 和跨设备同步。
- `operationId` 幂等设计应保留，真实接口也需要 idempotency key，避免重复扣金币。
- 需要确认是否有“游客可看免费内容但不能金币解锁”的产品规则。如果有，应在 EntitlementController 扩展，不要让 PlayerPage 判断。

## Store / Recharge

当前模型：

- `StorePackageKind`：coins / vip。
- `StorePackage`：`id`、`kind`、`title`、`priceLabel`、`baseCoins`、`bonusCoins`、`originalPriceLabel`、`benefits`。
- `StoreRechargeData`：balance、coin packages、vip packages、tips。
- Store mock success 已写入 `EntitlementController.grantMockCoins`。

真实 API 建议：

- `GET /store/recharge-products?platform=android&locale=...`
- `POST /orders`
- `GET /orders/{orderId}`
- `POST /iap/google/verify`
- `POST /iap/apple/verify`
- `POST /iap/restore`

需要调整：

- `priceLabel/originalPriceLabel` 只是展示字段。真实商品需要增加 raw contract：`platformProductId`、`currencyCode`、`priceMicros`、`localizedPrice`、`originalPriceMicros`、`promotionId`、`promotionExpiresAt`。
- `totalCoins` 可用于 mock UI，但真实发放必须以后端订单/验单结果为准。
- bonus badge 计算应以服务端结构化字段为准，不应解析 title 或 price label。
- Store 的 VIP package 可以保留展示，但真实业务上会员商品列表最好由 Membership product API 管理，Store 只作为入口或聚合页。

## Membership

当前模型：

- `MembershipPlan`：`id`、`title`、`priceLabel`、`dailyPriceLabel`、`originalPriceLabel`、`badgeLabel`、`description`。
- `MembershipBenefit`：icon、title、highlight、description。
- `MembershipData`：isActive、hero、plans、benefits、tips。
- Membership mock success 已写入 `EntitlementController.grantMockMembership`。

真实 API 建议：

- `GET /membership/status`
- `GET /membership/products?platform=android&locale=...`
- `POST /orders`
- `POST /iap/*/verify`

需要调整：

- 会员状态和会员商品列表建议拆接口。商品列表可缓存，会员状态必须跟账号权益刷新。
- `dailyPriceLabel`、`priceLabel` 是营销展示，不能参与真实支付金额判断。
- 倒计时促销需要服务端提供 `promotionStartsAt/promotionEndsAt/serverTime`，否则客户端本地倒计时容易被时间篡改。
- 权益文案可以由服务端配置，但真实权益是否生效仍要看 entitlement/membership status。

## Wallet

当前模型：

- `WalletData`：coins、bonus、autoUnlockNextEpisode、transactionRecords、consumptionRecords、coinRecords。
- `WalletRecord`：用 `WalletRecordType` 覆盖交易、消费、金币奖励三类记录。
- E3 后 Wallet 的余额/auto unlock 已向 shared entitlement state 收敛。

真实 API 建议：

- `GET /wallet`
- `GET /wallet/transactions?pageToken=...`
- `GET /wallet/consumption-records?status=spent|expired&pageToken=...`
- `GET /wallet/reward-coins?pageToken=...`
- `POST /wallet/reward-coins/{id}/claim`
- `PATCH /entitlements/settings/auto-unlock`

需要调整：

- `WalletRecord` 作为 union model 对 MVP 足够。真实 API 阶段建议 DTO 拆成 `TransactionRecordDto`、`ConsumptionRecordDto`、`RewardCoinRecordDto`，mapper 再转当前 UI model。
- Wallet 首页余额和 EntitlementState.coinBalance 的关系已基本明确：展示优先 shared entitlement。真实阶段需要决定余额刷新入口是 Wallet API 还是 Entitlement API 的聚合结果。
- `bonus` 目前仍由 Wallet mock 提供。真实阶段要明确 bonus 能否消费、是否过期、是否优先扣减。
- 交易/消费/奖励记录分页和空态需要独立 pageToken，不要共用一个 wallet page load。

## My list / Play history

当前模型：

- `MyListTab`：collection / play。
- `MyListItem`：id、title、introduction、coverAssetPath、currentEpisode、episodeCount。
- `MyListController` 管理 tab、编辑态、selectedIds、批量删除、单项删除、左滑打开项、loading/error/empty/retry。

真实 API 建议：

- `GET /me/favorites?pageToken=...`
- `POST /me/favorites`
- `DELETE /me/favorites/{dramaId}`
- `DELETE /me/favorites:batch`
- `GET /me/play-history?pageToken=...`
- `DELETE /me/play-history/{historyId}`

需要调整：

- `currentEpisode` 是展示字段，不等同于真实播放进度。真实进度应来自 playback progress/history 接口。
- 收藏和播放历史可以复用 UI model，但 remote DTO 建议拆开。收藏记录按 dramaId 删除，播放历史可能按 historyId 或 episodeId 删除。
- `coverAssetPath` 同 Home，需要 asset/network 资源归一化。
- My list 删除 mutation 的 optimistic update 与失败回滚策略需要在接 API 前设计清楚。

## Auth / Profile

当前模型：

- `AuthSession`：guest/logged-in。
- `AuthUser`：id、nickname、avatarAssetPath、provider。
- `ProfileState`：profile 摘要展示，包括会员卡、金币卡、语言入口。
- ProfilePage 已从 AuthState 合成登录展示，ProfileController 不拥有登录真相。

真实 API 建议：

- `POST /auth/device`
- `POST /auth/oauth/google`
- `POST /auth/oauth/facebook`
- `POST /auth/logout`
- `DELETE /account`
- `GET /profile`
- `GET /entitlements`
- `GET /wallet`

需要调整：

- Auth model 不应包含 token，这是正确的。真实 token 应在 core/auth/network 层管理，UI 只读 session/user。
- Profile 页面未来应是聚合展示：Auth 提供账号，Profile API 提供昵称/头像/地区，Entitlement/Membership 提供会员，Wallet 提供金币。当前 ProfileController mock 只适合 MVP。
- `ProfileCoinsState.balance` 仍可能和 Wallet/Entitlement 不一致。真实 API 阶段应统一派生，避免 Profile 卡片显示旧余额。
- 账号注销需要服务端状态和本地 session 清理分离，不能只靠 UI 弹窗。

## Localization

当前边界：

- `AppLocalizations`：固定 UI 文案。
- 内容标题/简介/剧集名：应由内容接口按 locale 返回。
- 字幕：应由 playback source 或 episode detail 返回 subtitle tracks。

真实 API 建议：

- `GET /localization/bundles/{locale}?version=...`
- 内容接口统一带 `locale` 参数。
- 播放源接口返回 `subtitleTracks`，包含 `language`、`label`、`url`、`format`、`isDefault`。

需要调整：

- 当前手写 `AppLocalizations` 可作为 fallback 保留。远程 JSON 包不应替代基础 fallback。
- 固定语言包 version check、download、cache、fallback 需要单独 controller/repository，不要和内容多语言混在一起。
- 内容 locale、字幕 language、UI locale 可以不同，需要在 API request header / query 里明确。

## Cross-cutting Data Contract Rules

1. UI / Page / Controller 不直接依赖 Dio、HTTP DTO 或 JSON。
2. data 层负责 remote datasource、DTO、mapper、repository implementation。
3. domain model 保持展示和业务语义稳定，不能把接口字段原样泄漏到 presentation。
4. 所有价格必须 raw/display 拆分：display label 只展示，真实金额来自订单/支付平台/服务端。
5. 播放源必须带 `sourceId/expiresAt/cachePolicy/preloadPolicy`，不能长期缓存签名 URL。
6. 权益、钱包、会员状态以后端刷新为准；客户端 mock success 只能驱动 MVP。
7. 图片、poster、cover、avatar、preview sprite 建议统一为 media resource contract，避免 asset path 与 remote URL 到处混用。
8. 分页统一使用 pageToken/cursor，不建议让客户端根据 offset 推断服务端分页。
9. 错误必须映射为可展示 UI state：auth、entitlement、payment、playback source、network timeout、offline、5xx 应有不同处理策略。

## P0 / P1 / P2

### P0

暂无。当前 mock contract 没有发现会阻塞真实 API 接入的结构性问题。

### P1

1. **补 DTO / mapper / remote datasource skeleton**：先为 Home/Drama 或 Player source 做一条真实 API skeleton，不立即替换 mock。
2. **统一 media resource 表达**：`coverAssetPath/avatarAssetPath/posterAssetPath` 等在真实阶段需要 asset/url 归一化。
3. **支付商品 raw/display 拆分**：Store/Membership 需要 `platformProductId/currency/priceMicros/localizedPrice/promotion` 等结构化字段。
4. **播放源 contract 对齐服务端规范**：确保 `sourceId/expiresAt/subtitleTracks/previewSprite/aspectRatio/preloadPolicy/cachePolicy` 都有 mapper 位置。
5. **Profile 聚合来源收口**：Profile 会员卡和金币卡后续应从 Auth/Entitlement/Wallet/Profile API 派生。
6. **Wallet record DTO 细分**：transaction/consumption/reward coin 远程 DTO 拆开，避免 union model 过早绑定接口。
7. **My list mutation 语义明确**：收藏批删、播放历史左滑删除要明确 endpoint、idempotency 和失败回滚。

### P2

1. Server preload manifest mock 和全局播放资源调度系统落地。
2. Remote localization bundle、fixed bundle version check 和本地 cache。
3. Subtitle tracks、preview sprite/VTT、seek thumbnail 的真实接口接入。
4. 播放进度本地保存与服务端同步冲突解决。
5. 支付订单、退款、撤销、权益回收的完整状态机。
6. API debug panel / network inspector / resource timing 面板。

## Defer

- 不在本轮引入真实 API client。
- 不把 mock repository 直接替换成远程实现。
- 不做 local HLS cache/proxy 生产化。
- 不实现真实 IAP/验单/订单。
- 不迁移 ARB/gen-l10n。
- 不重构现有 UI 和播放器主流程。

## 建议下一轮 / 待派任务

### Completed: Network Contract Phase B

状态：已完成。

目标：把 `core/network` 对齐服务端最新接口规范，但仍不接真实业务 API，不替换 mock repository。

已完成范围：

1. 新增 `ApiRequestContext` / provider，统一提供 `Device-Id`、`Lang`、`Platform`、`App-Version`、`accessToken?`。
2. `ApiClient` 所有请求默认带：
   - `Device-Id`
   - `Lang`
   - `Platform`
   - `App-Version`
   - `Accept: application/json`
   - body 请求带 `Content-Type: application/json`
3. 新增 `ApiAuthPolicy`：
   - 登录、第三方登录、刷新 token 不带 `Authorization`。
   - 登录后的业务接口带 `Authorization: Bearer xxx`。
   - 当前 skeleton 默认不要强制 token，避免破坏 mock 和远程骨架测试。
4. 服务端 envelope 统一为：
   ```json
   {
     "code": 0,
     "message": "success",
     "data": null
   }
   ```
   `code: 0` 是唯一成功码；不能再把 `200` 当业务成功码。
5. `ApiException` 增加 `businessCode`，并保留服务端 `message`。
6. 业务错误码按 4 位数字处理：
   - `1001` 参数错误
   - `1002` 请求频繁
   - `1003` 签名 / 验签失败
   - `1004` 系统异常
   - 后续 `2xxx` 用户域、`3xxx` 内容域、`4xxx` 金币/任务/福利域只记录并透传，不在网络层硬编码业务 UI。
7. 更新 `docs/api-integration-plan.md`、`docs/mock-data-and-api-readiness-review.md`
   和 `docs/networking-guidelines.md`，让 header、envelope、错误码和实现一致。
8. 已补网络层单测：
   - 所有请求自动带四个基础 header。
   - auth required 时带 `Authorization`。
   - auth none 时不带 `Authorization`。
   - `code: 0` 成功。
   - `code: 200` 应作为业务失败处理。
   - `code: 1001` 抛出 `ApiException.businessCode == 1001`。
   - `data: null` 可以被 decoder 正常处理。

限制：

- 不接真实登录。
- 不接真实 token refresh。
- 不接真实业务接口。
- 不改 UI。
- 不替换 `MockDramaRepository` / 其他 mock repository。
- 不把 token 存储、secure storage、401 refresh 队列混进本轮。

已验证：

```bash
dart format lib test integration_test
flutter analyze
flutter test
```

### 已完成: API Skeleton Phase A

## API Skeleton Phase A 状态

已完成 Home / Drama 第一条 mock -> remote 迁移骨架：

- 新增 Home/Drama DTO：category、drama item、feed page。
- 新增 DTO -> domain mapper：远程 category/feed 可转换为当前 `DramaCategory`、`Drama`、`DramaFeedPage`。
- 新增 `DramaRemoteDataSource`：预留 `GET /home/categories` 和 `GET /home/feed`。
- 新增 `RemoteDramaRepository`：实现现有 `DramaRepository`，上层仍只感知 domain model。
- `dramaRepositoryProvider` 增加 `USE_REMOTE_DRAMA_API` 编译期开关，并兼容 Phase A 早期 `USE_REMOTE_API`；默认仍返回 `MockDramaRepository`，不影响当前 Home UI。
- 已补 mapper/repository/provider 默认行为测试。

仍然 defer：

- 真实 baseUrl、鉴权 header、token refresh、locale header。
- 全量 DTO 体系和其他 feature 的 remote implementation。

## MediaResource Phase A 状态

已完成 Home / Drama 图片资源身份的小收口：

- 新增 `MediaResource` / `MediaResourceType`，只表达 asset/network 与资源值，不负责缓存、占位、错误图或加载策略。
- `Drama` 新增 `coverResource`，旧 `coverAssetPath` 仍保留兼容 mock 和旧 UI。
- mock `Drama` 默认自动生成 `MediaResource.asset(...)`。
- remote mapper 将 `coverUrl` 映射为 `MediaResource.network(...)`，缺 `coverUrl` 时使用 `posterUrl`，两者都缺失时回落到默认 asset。
- Home 卡片封面已最小适配 `Image.asset` / `Image.network`，并保留现有布局、圆角和失败 fallback。

仍然 defer：

- 不引入 `cached_network_image`，不做图片缓存系统。
- 不迁移 PlayerContent、Profile、My list、Wallet 等其他图片字段。
- 不处理 CDN 图片参数、渐进加载、统一 placeholder 组件和预加载策略。

## API Skeleton Phase B 状态

已完成 Player / Drama Detail / Playback Source 的远程骨架，但默认运行链路仍保持 mock：

- 新增 Player DTO：剧详情、剧集、For You feed item/feed page、播放源、字幕轨道、seek preview sprite。
- 新增 DTO -> domain mapper：远程数据可以转换为现有 `PlayerContent`、`PlayerEpisode`、`PlayerFeedItem`、`PlaybackSource`。
- 新增 `PlayerRemoteDataSource`：预留 `GET /dramas/{dramaId}`、`GET /dramas/{dramaId}/episodes`、`GET /feed/for-you`。
- 新增 `PlaybackSourceRemoteDataSource`：预留 `GET /episodes/{episodeId}/playback-source`，按播放源接口要求使用 `ApiAuthPolicy.required`。
- 新增远程 repository：`RemotePlayerContentRepository`、`RemotePlayerFeedRepository`、`RemotePlayerPlaybackSourceRepository`，均实现现有 domain repository interface。
- Player 相关 provider 增加 `USE_REMOTE_PLAYER_API` 编译期开关；默认值仍为 `false`，因此当前 UI、播放器和 mock flow 不受影响。
- `PlayerFeedItem.id` 在 remote mapper 中使用稳定 key，优先使用服务端 `feedItemId`，否则按 `mode + dramaId + episodeId` 生成，避免列表 index 污染 session window。
- `PlaybackSource.cacheKey` 已预留 `sourceId` 维度，避免未来同 URL/不同 source 版本的缓存和预热状态混淆。

## API Skeleton Phase B Review / Contract Tightening

已完成 Phase B 的小范围 contract 收口：

- `PlaybackSourceDto` 增加 `isAvailable`、`accessStatus`、`reasonCode`，用于承接服务端 access denied / unavailable / blocked 等拒播语义。
- `PlayerEpisodeDto` 增加 `accessStatus`、`reasonCode` 预留字段，后续可把下架、地区限制、会员限制等原因映射到 Entitlement，而不是让 PlayerPage 猜。
- `PlaybackSourceMapper` 收紧不可播放源处理：
  - 缺 `hlsUrl` 时抛出 source resolve error，不生成可播放 source。
  - `expiresAt` 已过期时抛出 source resolve error，避免把过期签名 URL 当正常播放源。
  - `isAvailable=false` 或 `accessStatus=denied/blocked/unavailable` 时抛出 source resolve error，交由上层进入现有 retry/unavailable/entitlement 流程。
- 补充测试确认同一个 HLS URL 但不同 `sourceId` 会生成不同 `cacheKey`。
- 补充测试确认 playback source remote datasource 使用 `ApiAuthPolicy.required`，且服务端 envelope 非 `code:0` 时保留 `ApiException.businessCode`。

仍然 defer：

- 不接真实 Player API，不启用真实 baseUrl，不替换 mock provider 默认行为。
- 字幕轨道、preview sprite、cachePolicy、preloadPolicy 只完成 contract/mapper，不接播放器 UI。
- `PlayerContent` 的 poster/background 仍沿用当前 asset fallback；统一 `MediaResource` 迁移留到后续图片资源阶段。
- 播放源 refresh、source 过期重拉、backup HLS URL fallback、真实 entitlement/access API 仍 defer。

## API Skeleton Phase C 状态

已完成 My list / Play history 远程骨架，但默认运行链路仍保持 mock：

- 新增 DTO：收藏条目、播放历史条目、分页结果、mutation 响应。
- 新增 DTO -> domain mapper：远程收藏和播放历史可以转换为当前 `MyListItem`。
- `MyListItem` 增加 `coverResource`，remote `coverUrl` 映射为 `MediaResource.network`，旧 UI 仍使用 `coverAssetPath` 兜底，不把网络 URL 伪装成 asset。
- 新增 `MyListRemoteDataSource`：预留 `GET /me/favorites`、`POST /me/favorites`、`DELETE /me/favorites/{dramaId}`、`DELETE /me/favorites:batch`、`GET /me/play-history`、`DELETE /me/play-history/{historyId}`。
- 新增 `RemoteMyListRepository`，实现现有 `MyListRepository`，上层仍只感知 domain model。
- `myListRepositoryProvider` 增加 `USE_REMOTE_MY_LIST_API` 编译期开关；默认值仍为 `false`，不影响当前 My list UI 和交互。
- 收藏条目 id 优先使用 `dramaId`，保证删除接口能明确 drama 维度；播放历史优先使用 `historyId`，缺失时用 `dramaId + episodeId` 生成稳定展示 id。
- 播放历史 DTO 已预留 `progressMs`、`durationMs`、`progressPercent`，当前 UI 暂不展示，为后续继续观看和播放进度同步准备。

仍然 defer：

- 不接真实 My list / Play history API，不启用真实 baseUrl，不替换 mock provider 默认行为。
- MyListController 仍保持当前本地乐观删除交互；远程 mutation 失败回滚、404 幂等业务码处理后续再接。
- 播放历史和 `PlaybackProgressRepository` 暂不合并，本轮只保留字段契约。
- My list 网络图 UI 渲染、图片缓存、分页加载更多和本地缓存仍 defer。

## API Skeleton Phase C Review / Mutation Tightening

已完成 My list / Play history 的 contract review 和 mutation 语义收口：

- Favorite DTO 已覆盖 `favoriteId`、`dramaId`、标题、简介、封面、画幅、总集数、最新集数、标签、角标、创建时间。
- Play history DTO 已覆盖 `historyId`、`dramaId`、`episodeId`、标题、简介、封面、画幅、当前集、总集数、`progressMs`、`durationMs`、`progressPercent`、更新时间。
- Favorite item 的 domain `id` 优先使用 `dramaId`，因为当前删除收藏接口是 `DELETE /me/favorites/{dramaId}`；`favoriteId` 只保留为服务端收藏记录 id。
- Play history item 的 domain `id` 优先使用 `historyId`，没有 `historyId` 时才用 `history:{dramaId}:{episodeId}` 做稳定展示 id；删除播放历史必须使用 `historyId`。
- `MyListRemoteDataSource` 的收藏/播放历史查询和删除 mutation 均使用 `ApiAuthPolicy.required`。
- 批量删除收藏请求体使用 `dramaIds`，和当前接口草案保持一致；如果后续服务端改为 favoriteIds，需要只调整 data/mapper/repository 边界，不应让 UI 感知。

真实 API 接入时建议：

- MyListController 当前仍是本地乐观删除。接真实 mutation 后，应在 controller 内统一调用 repository，并处理失败回滚。
- 删除失败、重复删除、已删除/404 可按业务码做幂等成功处理，但本阶段只透传 `ApiException.businessCode`。
- 播放历史删除和播放进度同步不要混在一起；`PlaybackProgressRepository` 与 Play history 的合并仍留到真实接口阶段。

## API Skeleton Phase D 状态

已完成 Wallet / Store / Membership / Entitlement 商业链路的远程骨架，默认运行链路仍保持 mock：

- Wallet：
  - 新增钱包余额、交易流水、消费记录、奖励金币、分页和设置 DTO。
  - 新增 `WalletRemoteDataSource`，预留 `GET /wallet`、`GET /wallet/transactions`、`GET /wallet/consumption-records`、`GET /wallet/reward-coins`、`POST /wallet/reward-coins/{id}/claim`、`PATCH /entitlements/settings/auto-unlock`。
  - 新增 `RemoteWalletRepository`，实现当前 `WalletRepository.fetchWallet()`。
  - 消费记录 `coverUrl` 映射为 `MediaResource.network`，当前 UI 仍保留 asset fallback。
- Store：
  - 新增充值商品、聚合数据、创建订单请求和订单 DTO。
  - DTO 保留 `platformProductId`、`priceMicros`、`currencyCode`、促销和原价字段，UI 继续使用 `localizedPrice` 展示。
  - 新增 `StoreRemoteDataSource`，预留 `GET /store/recharge-products` 和 `POST /orders`；商品列表本阶段按可公开查看处理，创建订单使用 `ApiAuthPolicy.required`。
  - 新增 `RemoteStoreRepository`，实现当前 `StoreRepository.fetchRechargeData()`。
- Membership：
  - 新增会员商品、会员状态、会员权益和聚合数据 DTO。
  - 新增 `MembershipRemoteDataSource`，预留 `GET /membership/products` 和 `GET /membership/status`；商品列表按可公开查看处理，状态使用 `ApiAuthPolicy.required`。
  - 新增 `RemoteMembershipRepository`，实现当前 `MembershipRepository.fetchMembership()`。
- Entitlement：
  - 新增权益状态、访问决策、解锁请求和解锁响应 DTO。
  - 新增 `EntitlementRemoteDataSource`，预留 `GET /entitlements`、`POST /entitlements/unlock-episode`、`PATCH /entitlements/settings/auto-unlock`，全部使用 `ApiAuthPolicy.required`。
  - 新增 `RemoteEntitlementRepository`，实现当前 `EntitlementRepository`。远程实现中的 `grantMockCoins/grantMockMembership` 不做本地发放，只刷新服务端权益快照；真实支付成功仍必须经过订单/验单/权益刷新。
- Provider：
  - 增加 `USE_REMOTE_WALLET_API`、`USE_REMOTE_STORE_API`、`USE_REMOTE_MEMBERSHIP_API`、`USE_REMOTE_ENTITLEMENT_API` 开关。
  - 默认全部为 false，当前 UI、mock purchase、Player unlock flow 不受影响。

已补测试：

- DTO fromJson、mapper、provider 默认 mock / remote override。
- Wallet / Store order / Membership status / Entitlement 接口的 `ApiAuthPolicy`。
- `code != 0` 时保留 `ApiException.businessCode`。

仍然 defer：

- 真实 baseUrl、真实登录 token、401 refresh 队列。
- Google / Apple IAP SDK、订单状态机、验单和权益发放。
- Store / Membership 商品接口是否必须登录的最终产品策略。
- Wallet 记录分页加载、奖励领取 UI 状态机和失败回滚。
- Profile 会员卡/金币卡从 Auth/Profile/Entitlement/Wallet 聚合派生。
- Entitlement 真实 access 接口、source refresh、服务端幂等业务码细分。

## API Skeleton Phase D Review / Commerce Contract Tightening

已完成商业链路远程骨架的 contract review 和小范围收口：

- 价格 raw/display 分离：
  - Store / Membership 商品 DTO 和 domain 均保留 `priceMicros`、`currencyCode`、`localizedPrice`、`originalPriceMicros`、`localizedOriginalPrice`。
  - Mapper 只透传 raw 字段，不从 `localizedPrice` 反推金额；UI 仍可继续使用 localized label 展示。
- Google / Apple 商品兼容：
  - Store / Membership 商品补充 `basePlanId`、`offerId`、`productType` 预留字段。
  - Store 金币商品可表达 `consumable`；Membership 商品可表达 `subscription`、base plan 和 offer。
  - `enabled`、`sortOrder`、促销 id / 促销结束时间继续保留。
- Order skeleton 安全边界：
  - `OrderDto.status` 仅表达订单状态快照，例如 pending / paid / failed / cancelled / verifying。
  - 创建订单不等于支付成功，也不等于权益已发放；真实金币/会员权益必须等平台支付、服务端验单和 entitlement refresh。
- Entitlement mapper：
  - 已覆盖 `allowPlay`、`goMembership`、`showCoinUnlockDialog`、`showRechargeDialog`、`autoUnlockAndPlay`、`waitUnlock`。
  - `insufficientCoins` 映射充值弹窗，`membershipRequired` 映射会员流程，`alreadyUnlocked/success` 映射允许播放，`unavailable` 不会误映射为可播放。
- Wallet 与 Entitlement 真相边界：
  - Wallet remote repository 只返回钱包聚合数据，不写入 mock entitlement state。
  - Entitlement remote repository 不依赖 mock repository 内存状态。
  - `PATCH /entitlements/settings/auto-unlock` 可以被 Wallet/Entitlement 共用，但最终真相是服务端 entitlement/settings。
- Auth policy：
  - Wallet、Store 创建订单、Membership status、Entitlement state/unlock/settings 均使用 `ApiAuthPolicy.required`。
  - Store / Membership 商品列表当前按“允许未登录浏览”假设使用 `ApiAuthPolicy.none`；如果产品要求登录展示，只需调整 data source，不应影响 UI。
- 分层边界：
  - DTO 仍只存在 data 层，remote repository 输出现有 domain model。
  - UI / Controller 不 import remote datasource，也不直接处理 DTO。

仍然 defer：

- 真实 IAP SDK、验单、订单轮询、退款/撤销、权益发放。
- `bonusBalance` 是否可消费、是否优先扣、是否会过期，以及赠币过期流水口径。
- 商品列表是否必须登录、是否按地区/语言/平台差异下发。
- Entitlement 真实 access 接口、服务端幂等业务码、失败重试策略。
- Wallet 记录分页、领取奖励、订单到账后刷新钱包/会员/Profile 聚合展示。

## API Skeleton Phase E 状态

已完成 Auth / Profile / Session / Token 远程骨架，默认运行链路仍保持 mock：

- Auth：
  - 新增 `AuthUserDto`、`AuthTokenDto`、`AuthSessionDto` 以及 device login、OAuth login、refresh、logout、delete account request DTO。
  - 新增 `AuthRemoteDataSource`，预留 `POST /auth/login/device`、`POST /auth/login/oauth`、`POST /auth/refresh`、`GET /auth/session`、`POST /auth/logout`、`DELETE /account`。
  - 新增 `RemoteAuthRepository`，实现当前 `AuthRepository`，输出仍是 `AuthSession` / `AuthUser`。
  - token 只保留在 data/core 边界；`AuthSession` 不暴露 access token，页面不接触 token。
  - `AuthUser.avatarUrl` 映射为 `MediaResource.network`，当前 UI 仍可使用既有 asset fallback。
- Profile：
  - 新增 `ProfileSummary` domain、`ProfileRepository`、`ProfileSummaryDto`、`ProfileMapper`、`ProfileRemoteDataSource`、`RemoteProfileRepository`。
  - 预留 `GET /profile`，用于后续账号资料、会员摘要、钱包摘要、语言/地区等聚合展示。
  - 当前 `ProfilePage` 仍由 AuthState + ProfileController mock 合成展示，不在本阶段强行接远程 Profile。
- Provider：
  - 增加 `USE_REMOTE_AUTH_API`、`USE_REMOTE_PROFILE_API` 开关。
  - 默认全部为 false，AuthPage / AccountPage / ProfilePage UI 行为不变。
- Auth policy：
  - 登录、第三方登录、刷新 token 使用 `ApiAuthPolicy.none`，不带 `Authorization`。
  - session、logout、delete account、profile 使用 `ApiAuthPolicy.required`。

已补测试：

- Auth/Profile DTO fromJson、mapper、provider 默认 mock / remote override。
- device login、OAuth login、refresh、session、logout、delete account、profile 的 auth policy。
- `code != 0` 时保留 `ApiException.businessCode`。

仍然 defer：

- 真实 Google / Facebook SDK。
- secure storage、refresh token queue、401 并发刷新和本地 session 持久化。
- 真实 device id、app version、token 注入到 `ApiRequestContext`。
- Profile 会员卡/金币卡从 Auth/Profile/Entitlement/Wallet 的真实接口聚合。
- logout/delete account 远程失败后的全局 cache 清理和播放器资源释放策略。

## API Skeleton Phase E Review / Session Contract Tightening

已完成 Auth / Profile / Session / Token 远程骨架的 contract review 和小范围收口：

- Token ownership：
  - `AuthTokenDto` 只存在 data 层，`AuthMapper` 不把 accessToken / refreshToken 映射进 UI 可见的 `AuthSession`。
  - `AuthController` 继续只消费 `AuthSession` / `AuthUser`，不把 token 当成页面状态。
  - `ApiRequestContext.accessToken` 当前仍是 mock/default 注入点；真实 token storage、refresh queue 和 logout 清理留到后续。
- Auth policy：
  - device login、OAuth login、refresh token 继续使用 `ApiAuthPolicy.none`。
  - session bootstrap、logout、delete account、profile 使用 `ApiAuthPolicy.required`。当前设计把 `GET /auth/session` 作为 token 校验/恢复接口；游客 bootstrap 如果后端允许，后续可新增 public bootstrap endpoint，不复用这个语义。
- Session contract：
  - authenticated payload 映射为 logged-in `AuthSession`。
  - guest / unauthenticated / malformed payload 映射为 guest，不把坏响应变成半登录状态。
  - HTTP 401 继续由 `ApiException.unauthorized` 透传给上层，不在 repository 静默吞掉。
- Logout / delete contract：
  - 远程 logout/delete 成功只代表服务端 session/account 操作完成，不等于本地所有 feature cache 已清理。
  - 失败仍保留 `ApiException.businessCode`；AccountPage 状态机本轮不改。
- ProfileSummary contract：
  - `ProfileSummary` 可表达 `userId`、`nickname`、`avatarResource`、`displayId`、language/region、membership summary、wallet summary、createdAt。
  - `avatarUrl` 映射为 `MediaResource.network`；缺失时回退到当前默认头像 asset。
  - Profile 的会员/钱包字段只是聚合展示快照，不拥有权益或余额真相。
- 分层边界：
  - 补充测试扫描 Auth/Profile application/presentation，防止 DTO / remote datasource 进入 UI 层。

仍然 defer：

- secure storage、refresh token queue、401 并发刷新。
- login success 后写入 token、logout/delete 后清除 token。
- logout/delete 后清理 Home/My list/Wallet/Entitlement/Profile cache 和播放器 session。
- 真实 Google / Facebook SDK 与 OAuth nonce 校验。
- Profile 会员卡/金币卡从真实 Auth/Profile/Entitlement/Wallet 聚合。

## API Skeleton 总回归 / Remote Contract Index

已新增 `docs/remote-contract-index.md`，作为当前远程契约总索引：

- 汇总 Network、Home/Drama、MediaResource、Player/Playback Source、My list、Wallet、Store、Membership、Entitlement、Auth/Profile 的 provider switch、remote repository、remote datasource、DTO/mapper、endpoint skeleton、auth policy、测试和 defer 项。
- 统一记录 `USE_REMOTE_XXX_API` 命名。Home/Drama 已新增 scoped `USE_REMOTE_DRAMA_API`，同时保留旧 `USE_REMOTE_API` fallback。
- 新增 `test/architecture/remote_contract_boundary_test.dart`，防止 DTO / remote datasource / remote repository 泄漏到 application/presentation。
- 当前没有发现 remote datasource 被 Page/Controller 直接 import，也没有发现 remote repository 返回 DTO 给 UI。

真实 API 联调前的 P0/P1/P2 准备清单以 `docs/remote-contract-index.md` 为准。
