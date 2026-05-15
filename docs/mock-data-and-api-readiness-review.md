# Mock Data And API Readiness Review

日期：2026-05-15

本文只评估当前 mock 数据、domain model、repository 边界到真实 API 的可迁移性，不接真实接口、不改 UI、不调整业务逻辑。结论基于当前 feature-first 结构、`docs/api-integration-plan.md`、`docs/player-source-and-cdn-spec.md`、`docs/entitlement-unlock-flow-plan.md` 和播放器资源调度相关文档。

## 总体结论

当前项目的 mock 到 API 迁移基础是健康的：大多数页面已经通过 domain model + repository + controller 访问数据，UI 没有直接依赖 Dio/HTTP，也没有在 Page 中散落大量 mock JSON。播放器、权益、商店、会员、钱包几个复杂模块已经形成比较清晰的“展示状态”和“业务真相”边界。

真正接 API 前不建议直接替换 mock repository。更稳的路径是先补 `remote datasource -> DTO -> mapper -> repository implementation` 这一层，让 presentation/application 继续只感知 domain model。这样可以避免接口字段、价格金额、签名播放源、支付订单状态直接泄漏到 UI。

当前没有阻塞真实接口接入的 P0，但有若干 P1 数据契约需要在 Phase A/B 前收口，尤其是图片/视频资源 URL 归一化、支付价格 raw/display 拆分、Profile 聚合来源、Wallet 记录细分、播放源 sourceId/expiresAt/字幕/preview sprite 的真实字段映射。

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

## 建议下一轮

建议下一轮做 **API Skeleton Phase A**，只补基础设施，不替换 mock：

1. 新增 `core/network`：ApiClient/Dio provider、header、timeout、ApiException 映射。
2. 选 Home/Drama 做第一条 remote datasource + DTO + mapper skeleton。
3. 保持 feature flag 默认 mock，remote implementation 只在测试中验证 mapper。
4. 同步定义 `MediaImage` 或等价资源模型，先解决 asset/url 归一化问题。

这样能最小风险验证“mock -> remote”的形状，而不会影响当前已验收 UI 和播放器链路。
