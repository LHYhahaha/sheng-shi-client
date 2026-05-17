# API Integration Architecture Plan

This document defines how the client should move from feature mock data to real
server APIs. It is a planning document only. It does not connect real APIs,
change UI, replace mock repositories, change payment/IAP behavior, or modify
player playback logic.

## 1. Overall Architecture

The project should keep the existing feature-first structure and replace mock
data one boundary at a time.

```text
presentation/page/widget
  -> application controller/state
    -> domain repository interface
      -> data repository implementation
        -> remote data source
          -> core/network ApiClient
```

Rules:

- UI, pages, widgets, and controllers must not import `Dio`, parse JSON, or
  create remote repositories directly.
- Domain keeps entities and repository interfaces.
- Data owns DTOs, remote data sources, mappers, and repository implementations.
- Application controllers only consume domain models and expose loadable state
  or feature-specific state.
- `core/network` owns `ApiClient`, base URL, headers, timeout, token injection,
  response envelope decoding, retry policy, and `ApiException` mapping.
- Mock and remote implementations must both implement the same domain
  repository interface. Provider switching should happen in the feature data
  provider, behind environment or feature flags.

Recommended remote file pattern:

```text
lib/features/<feature>/
  domain/
    <feature>_repository.dart
    <domain_models>.dart
  data/
    dto/
      <name>_dto.dart
    remote/
      <feature>_remote_data_source.dart
    mapper/
      <feature>_mapper.dart
    remote_<feature>_repository.dart
    mock_<feature>_repository.dart
    <feature>_repository_provider.dart
```

Provider policy:

- Keep current mock providers as the default until each backend path is ready.
- Add remote implementations without changing presentation code.
- Prefer a feature flag such as `USE_REMOTE_API=true` or an app environment
  switch before replacing mock behavior.

## 2. Network Contract

Current network skeleton:

- `lib/core/network/api_client.dart`
- `lib/core/network/api_client_provider.dart`
- `lib/core/network/api_exception.dart`
- `lib/core/network/api_page.dart`
- `docs/networking-guidelines.md`

Required request headers:

All requests, including login, third-party login, and refresh token:

- `Device-Id`: stable **install id** (persisted per app install, not hardware ID; see A4).
- `Lang`: app/content language, currently `en`, `es`, `pt`, or `hi`.
- `Platform`: `ios`, `android`, or `web`.
- `App-Version`: native app version, for example `1.0.0`.
- `Accept: application/json`.
- `Content-Type: application/json` for body requests.

Authenticated business requests, excluding login, third-party login, and
refresh token:

- `Authorization: Bearer <accessToken>`.

Optional client diagnostics headers should only be added after the server
confirms support:

- `X-Timezone`: IANA timezone.
- `X-Request-Id`: optional client-generated request id.

Response envelope:

```json
{
  "code": 0,
  "message": "success",
  "data": null
}
```

- `code: 0` is the only success code.
- Failure responses use a four-digit business code and `data: null` unless a
  specific endpoint defines otherwise.
- Four-digit business codes use the format: domain digit + module digit +
  two-digit sequence. Examples: `1001`, `3102`, `4205`.
- Current reserved domains: `0` global, `1` admin, `2` app user, `3` short
  drama content, `4` coins/tasks/welfare.
- Current global examples: `1001` parameter error, `1002` request too frequent,
  `1003` signature/verification failed, `1004` system exception.

Timeout defaults:

- Normal JSON APIs: 8-12s connect/receive.
- Playback source refresh: 5-8s.
- Receipt verification and order polling: 10-20s because stores can be slow.

Error mapping:

- `401 unauthorized`: token refresh if available; otherwise cleanup + guest
  bootstrap (not empty logged-out).
- `403 entitlement`: user lacks entitlement, membership, coins, or unlock.
- `403 source_expired`: signed playback source expired and can be refreshed.
- `404`: missing content/source/order. For playback source, show retry or
  unavailable depending on backend code.
- `409 conflict`: duplicate operation or idempotency conflict.
- `422 validation`: request invalid; show business message where safe.
- `408`, timeout, network offline, `5xx`: retryable according to retry budget.
- Unknown malformed responses: `badResponse`, generic failure UI.

UI mapping:

- Retryable errors become retry actions in controllers.
- Auth failures are handled by auth/session controllers, not by pages.
- Entitlement failures should open paywall/unlock surfaces only where product
  flow expects it.
- Payment verification errors must never be treated as success on the client.

## 3. API Module Matrix

| Module | Current mock / feature boundary | Future repository interface | Suggested endpoints | Auth | Cache | Player/payment impact |
| --- | --- | --- | --- | --- | --- | --- |
| Auth / Account | `features/auth/data/mock_auth_repository.dart` | `AuthRepository` | `GET /auth/session`, `POST /auth/login/device`, `POST /auth/login/oauth`, `POST /auth/logout`, `DELETE /account` | Optional for session, required for logout/delete | Session token only | Controls Profile, My list, wallet, purchases |
| Home feed | `features/drama/data/mock_drama_repository.dart` | `DramaRepository` | `GET /home/categories`, `GET /home/feed` | Optional | Short memory/disk cache | Entry point to Player |
| Drama category/tag/filter | `DramaRepository` extension or new `DramaCatalogRepository` | New domain interface | `GET /dramas/categories`, `GET /dramas/tags`, `GET /dramas/search` | Optional | Categories/tags cacheable | Drives discovery |
| Drama detail | `features/player/data/mock_player_content_repository.dart` and drama mock | `PlayerContentRepository` / `DramaDetailRepository` | `GET /dramas/{dramaId}` | Optional | Detail can cache briefly | Player sheets and detail metadata |
| Episode list | `features/player/data/mock_player_feed_repository.dart` | `PlayerFeedRepository` | `GET /dramas/{dramaId}/episodes` | Optional | Brief cache, invalidate on entitlement change | Player PageView/feed |
| Playback source | `features/player/data/mock_player_playback_source_repository.dart` | `PlayerPlaybackSourceRepository` | `GET /playback/sources`, `POST /playback/sources/refresh` | Required or signed guest | By `expiresAt` only | Critical player path |
| Playback progress | `features/player/data/mock_playback_progress_repository.dart` | `PlaybackProgressRepository` | `GET /playback/progress`, `PUT /playback/progress` | Required for sync | Local temp + server sync | Resume and continue watching |
| My list / favorites | `features/my_list/data/mock_my_list_repository.dart` | `MyListRepository` | `GET /me/lists`, `POST /me/favorites`, `DELETE /me/favorites/{id}`, `DELETE /me/history/{id}` | Required | Memory; refresh after mutation | Collection/play history |
| Play history | My list play list mock | `MyListRepository` or `PlayHistoryRepository` | `GET /me/history`, `POST /me/history`, `DELETE /me/history/{id}` | Required | Memory; local optimistic entry optional | Continue watching |
| Profile | `features/profile/application/profile_controller.dart` currently reads local/mock auth-like state | `ProfileRepository` if profile grows | `GET /me/profile`, `PATCH /me/profile` | Required | Refresh on auth/profile changes | Header/account state |
| Wallet | `features/wallet/data/mock_wallet_repository.dart` | `WalletRepository` | `GET /wallet`, `GET /wallet/transactions`, `GET /wallet/consumption`, `GET /wallet/coins`, `PATCH /wallet/settings` | Required | Short cache; refresh after orders/unlocks | Coins, auto unlock |
| Store recharge products | `features/store/data/mock_store_repository.dart` | `StoreRepository` | `GET /store/recharge-products` | Optional/required by product | Cache with version | Purchase UI products |
| Membership products | `features/membership/data/mock_membership_repository.dart` | `MembershipRepository` | `GET /membership/products`, `GET /membership/status` | Optional for products, required for status | Products cacheable; status fresh | VIP paywall/profile |
| Orders | Not yet separated | New `OrderRepository` | `POST /orders`, `GET /orders/{orderId}`, `POST /orders/{orderId}/cancel` | Required | Do not cache active order status | Payment state |
| IAP receipt verification | Not implemented | New `IapRepository` | `POST /iap/verify`, `GET /iap/transactions/{id}` | Required | No cache except idempotency | Entitlement source of truth |
| Entitlement / unlock | Player paywall mock state | New `EntitlementRepository` | `GET /entitlements`, `POST /entitlements/unlock`, `GET /episodes/{id}/access` | Required | Refresh after purchase/unlock | Locked episode behavior |
| Localization fixed bundle | `lib/l10n/app_localizations.dart`, docs backlog | New `LocalizationRepository` | `GET /app/i18n/version`, `GET /app/i18n/bundle` | Optional | Persistent by version/checksum | Fixed UI copy |
| Content localization | Drama/player content mocks | Existing content repositories with `locale` | All content endpoints accept `locale` | Optional | Same as content cache | Titles/descriptions/tags |
| Subtitle tracks | Playback source spec | `PlayerPlaybackSourceRepository` | Included in playback source response | Follows playback auth | By source expiry | Player subtitle selection |

## 4. Module Details

### Auth / Account

Current mock:

- `AuthRepository`
- `MockAuthRepository`
- `AuthController`

#### Guest session & account link（产品模型，2026-05-17 设计）

App **不是**「未登录 = 无用户」。默认是 **游客账户 session**；用户主动登录是
**account link / upgrade**（游客数据合并到正式账号），不是客户端简单替换 token。

| 流程 | 客户端 | 服务端 |
| --- | --- | --- |
| App bootstrap | `Device-Id` 就绪 → **guest bootstrap**（无 token 或 bootstrap 专用接口） | 创建/恢复游客，返回 guest token + guestId |
| 游客使用 | 带 guest access token 调 `required` 接口（当前语义：任意有效 session token） | 按策略返回游客 entitlement/进度等 |
| 主动登录 | `POST login/*` 携带 **current guest session / guestId / deviceId** | link 游客 → 正式账号，合并数据 |
| 登录成功 | 存 authenticated token；**refresh** entitlement / wallet / profile / my list / playback progress | 返回正式 session |
| Logout | cleanup hooks → **guest bootstrap**（推荐同 device 新 guest session） | 返回 guest session |
| Refresh failed | clear token → cleanup → guest bootstrap → reload guest-safe 数据 | 可选 guest refresh |

推荐策略（待服务端确认）：logout 后 **重新 bootstrap guest**，不保留失效正式用户本地态。

Skeleton（无真实网络）：`GuestSessionBootstrap`、`AuthSessionKind`、`AuthTokenSessionKind`。

Future endpoints:

- `POST /auth/guest/session`（或等价 bootstrap，**待后端命名**）
  - Request: `deviceId`, `platform`, `appVersion`, `lang`；可选 install id。
  - Response: guest `accessToken`, `refreshToken`, `guestId`, `sessionId`.
  - Auth: `ApiAuthPolicy.none`。
- `POST /auth/guest/refresh`（若与 user refresh 分离）
  - Request: guest `refreshToken`.
  - Response: guest token 包。
- `GET /auth/session`
  - Request: auth token if available, device id.
  - Response: `isAuthenticated`, `user`, `token`, `serverTime`, `isNewUser`, `guestId`.
  - 有 token 时用 `required`；**无 token 的纯 bootstrap 必须走 guest bootstrap 接口**，不要与 session recovery 混用。
- `POST /auth/login/device`
  - Request: `deviceId`, `platform`, `appVersion`, `lang`, **`guestId`**, optional guest session proof.
  - Response: authenticated session（account link 后）。
- `POST /auth/login/oauth`
  - Request: `provider`, `idToken` or `accessToken`, `nonce`, `deviceId`,
    `platform`, `appVersion`, `lang`, **`guestId`**.
  - Response: authenticated session.
- `POST /auth/refresh`
  - Request: `refreshToken`（guest 或 user，由 token 类型决定）。
  - Response: token.
- `POST /auth/logout`
  - Request: refresh token/device id.
  - Response: guest session 或指示客户端再调 guest bootstrap。
- `DELETE /account`
  - Request: confirmation token or password if required.
  - Response: guest session；客户端 cleanup + guest bootstrap。

Errors:

- `401`: invalid/expired token.
- `409`: provider already linked or account conflict.
- `422`: invalid provider credential.
- `5xx/network`: retryable login/logout/delete failure.

Cache:

- Store tokens in secure storage in a later phase.
- Keep profile/session in memory; refresh on launch.

Phase E skeleton status:

- `AuthRemoteDataSource` and `RemoteAuthRepository` now exist behind
  `USE_REMOTE_AUTH_API`, with mock as the default provider path.
- Auth DTOs are confined to the data layer. `AuthTokenDto` is not mapped into
  UI-facing `AuthSession`; real token ownership remains in core/network/session.
- Device login, OAuth login, and refresh use `ApiAuthPolicy.none`; session,
  logout, and delete account use `ApiAuthPolicy.required`.
- Phase E review keeps `GET /auth/session` as token-backed session recovery.
  Guest bootstrap without token should be a separate explicit contract if
  backend needs it.
- Logout/delete account remote success does not by itself clear secure storage,
  feature caches, or player sessions. That global cleanup belongs to the later
  real session lifecycle phase.
- `ProfileSummaryDto`, `ProfileMapper`, `ProfileRemoteDataSource`, and
  `RemoteProfileRepository` now exist behind `USE_REMOTE_PROFILE_API`.
  Profile UI still uses the current mock/Auth composition until the real
  profile aggregation endpoint is ready.

### Home Feed

Current mock:

- `DramaRepository`
- `MockDramaRepository`
- `HomeFeedController`

Future endpoints:

- `GET /home/categories`
  - Request: `locale`, `region`, optional `abGroup`.
  - Response: `items: [{ id, title, sortOrder }]`.
- `GET /home/feed`
  - Request: `categoryId`, `pageToken`, `pageSize`, `locale`, `region`.
  - Response: `items`, `nextPageToken`.

Response item fields:

- `dramaId`, `title`, `description`, `coverUrl`, `posterUrl`
- `tags`, `viewCount`, `isExclusive`, `isHot`, `categoryIds`
- `firstEpisodeId`, `latestEpisodeNumber`, `totalEpisodes`
- Optional `accessPreview`: locked/free/member hints.

Errors:

- `404 category_not_found`
- `5xx/network/timeout` retryable

Cache:

- Cache categories and first page briefly.
- Feed can use stale-while-revalidate later, but MVP should keep controller
  state explicit.

### Drama Category / Tag / Filter

Future repository:

- `DramaCatalogRepository` or an extension of `DramaRepository`.

Future endpoints:

- `GET /dramas/categories`
- `GET /dramas/tags`
- `GET /dramas/search`

Request:

- `locale`, `region`, `categoryId`, `tagIds`, `keyword`, `sort`, `pageToken`,
  `pageSize`.

Response:

- `items`, `facets`, `nextPageToken`.

Cache:

- Categories/tags are versioned and cacheable.
- Search results are memory-only.

### Drama Detail

Current mock:

- `MockPlayerContentRepository`
- `PlayerContentRepository`

Future endpoint:

- `GET /dramas/{dramaId}`

Request:

- `locale`, optional auth token for access preview.

Response:

- `dramaId`, `title`, `description`, `synopsis`, `posterUrl`, `coverUrl`
- `tags`, `viewCount`, `episodeCount`, `isCollected`
- `accessSummary`, `recommendations`

Cache:

- Cache briefly, invalidate after favorite/unlock/membership changes.

### Episode List

Current mock:

- `MockPlayerFeedRepository`
- `PlayerFeedRepository`

Future endpoints:

- `GET /dramas/{dramaId}/episodes`
- `GET /player/for-you`

Request:

- Single drama: `dramaId`, `episodeId`, `locale`, optional `pageToken`.
- For You: `pageToken`, `pageSize`, `locale`, `region`, user profile signal.

Response fields:

- `itemId`, `drama`, `episode`, `access`
- `episode.id`, `episode.number`, `episode.title`, `durationMs`
- `posterUrl`, `backgroundUrl`, `isLocked`, `isUnavailable`, `unlockPrice`
- `nextPageToken` for feed mode.

Pagination:

- Single drama can return all episodes or ranged pages.
- For You must be cursor-based.

Player impact:

- Locked/unavailable/null-source items must not open, preload, or prepare media.
- For You and single drama session keys remain isolated.

### Playback Source

Current mock:

- `MockPlayerPlaybackSourceRepository`
- `PlayerPlaybackSourceRepository`
- `PlaybackSource`
- `docs/player-source-and-cdn-spec.md`

Future endpoint:

- `GET /playback/sources`
  - Query: `dramaId`, `episodeId`, `itemId`, `locale`, `deviceId`,
    `networkType`, `clientCapabilities`.
- `POST /playback/sources/refresh`
  - Body: `sourceId`, `refreshToken`.

Response must follow `docs/player-source-and-cdn-spec.md`:

- `episodeId`, `sourceId`, `hlsUrl`, `backupHlsUrls`, `expiresAt`
- `signedUrlRefreshEndpoint`, `refreshToken`
- `durationMs`, `width`, `height`, `aspectRatio`
- `codec`, `bitrateLadder`
- `posterUrl`, `thumbnailUrl`, `previewSpriteUrl`, `previewVttUrl`
- `subtitleTracks`, `audioTracks`
- `cachePolicy`, `preloadPolicy`
- `access`

Access rules:

- Locked/unavailable should return `access.status` and no playable `hlsUrl`, or
  return a non-playable source with explicit `status`.
- `403 entitlement` opens unlock/member UI only through controller state.
- `403 source_expired` attempts refresh.

Cache:

- Do not long-term cache playback source.
- Respect `expiresAt`.
- HLS preload uses `preloadPolicy` and local `PlayerPreloadConfig`.

### Playback Progress

Current mock:

- `InMemoryPlaybackProgressRepository`
- `PlaybackProgressRepository`

Future endpoints:

- `GET /playback/progress`
  - Query: `dramaId`, `episodeId`.
- `PUT /playback/progress`
  - Body: `episodeId`, `positionMs`, `durationMs`, `completed`, `updatedAt`.

Policy:

- Single drama can restore progress across sessions after product approval.
- For You should not restore across sessions unless product confirms.
- Local progress remains a short-lived fallback for offline/failed sync.

Errors:

- Sync failure is non-blocking for playback.
- `401` disables server sync until logged in.

### My List / Favorites / Play History

Current mock:

- `MyListRepository`
- `MockMyListRepository`

Future endpoints:

- `GET /me/favorites`
- `POST /me/favorites`
- `DELETE /me/favorites/{dramaId}`
- `GET /me/history`
- `POST /me/history`
- `DELETE /me/history/{itemId}`
- `DELETE /me/history/batch`

Request:

- Pagination: `pageToken`, `pageSize`.
- Mutations: `dramaId`, `episodeId`, optional idempotency key.

Response:

- `items`, `nextPageToken`; item fields should map to `MyListItem`.

Cache:

- Memory cache and optimistic delete allowed.
- Refresh after mutation or login/logout.

### Profile

Current state:

- `ProfileController` derives mock/profile display from auth-like state.

Future repository:

- Add `ProfileRepository` only when fields outgrow `AuthSession`.

Future endpoints:

- `GET /me/profile`
- `PATCH /me/profile`

Response:

- `userId`, `nickname`, `avatarUrl`, `membershipStatus`, `coinsBalance`,
  `language`, `createdAt`.

Cache:

- Refresh on app launch, auth change, purchase/unlock.

### Wallet

Current mock:

- `WalletRepository`
- `MockWalletRepository`

Future endpoints:

- `GET /wallet`
- `PATCH /wallet/settings`
- `GET /wallet/transactions`
- `GET /wallet/consumption`
- `GET /wallet/coins`

Request:

- `pageToken`, `pageSize`, `type`, `status`, date range.
- `PATCH /wallet/settings`: `autoUnlockNextEpisode`.

Response:

- Balance: `coins`, `bonusCoins`, `membershipPoints`, `autoUnlockNextEpisode`.
- Transaction record: `id`, `amount`, `currency`, `productName`, `status`,
  `createdAt`.
- Consumption record: `id`, `dramaId`, `episodeId`, `posterUrl`, `title`,
  `coins`, `consumeType`, `createdAt`, `expiresAt`.
- Reward coin record: `id`, `amount`, `source`, `expiresAt`, `canCheckIn`.

Cache:

- Wallet summary should refresh after order, unlock, membership change.
- History pages can cache per page briefly but must support retry/empty states.

### Store Recharge Products

Current mock:

- `StoreRepository`
- `MockStoreRepository`

Future endpoints:

- `GET /store/recharge-products`

Request:

- `platform`, `locale`, `currency`, `appVersion`.

Response:

- `balance`, `packages`, `tips`, `restoreAvailable`.
- Package fields: `productId`, `storeProductId`, `coins`, `bonusCoins`,
  `price`, `currency`, `displayPrice`, `badge`, `sortOrder`.

Cache:

- Cache by product version and platform.
- Refresh when app starts or store page opens.

Payment impact:

- Product list is not proof of purchase.
- Purchase must flow through order + store receipt verification.

### Membership Products

Current mock:

- `MembershipRepository`
- `MockMembershipRepository`

Future endpoints:

- `GET /membership/products`
- `GET /membership/status`

Response:

- Product fields: `planId`, `storeProductId`, `period`, `price`,
  `displayPrice`, `trial`, `discount`, `benefits`, `isRecommended`.
- Status fields: `isActive`, `planId`, `expiresAt`, `autoRenew`,
  `willExpireAt`, `sourcePlatform`.

Cache:

- Products cacheable by version.
- Status must refresh after receipt verification, restore, refund, or account
  switch.

### Orders

Future repository:

- `OrderRepository`

Future endpoints:

- `POST /orders`
- `GET /orders/{orderId}`
- `POST /orders/{orderId}/cancel`

Create order request:

- `productId`, `productType` (`coins`, `membership`, `episode_unlock`)
- `platform`, `currency`, `idempotencyKey`, optional `dramaId`, `episodeId`.

Response:

- `orderId`, `status`, `amount`, `currency`, `expiresAt`, `paymentPayload`.

Errors:

- `409 duplicate_idempotency_key`
- `422 invalid_product`
- `403 entitlement_not_allowed`

### IAP Receipt Verification

Future repository:

- `IapRepository`

Future endpoints:

- `POST /iap/verify`
- `GET /iap/transactions/{transactionId}`
- `POST /iap/restore`

Verify request:

- `platform`: `ios` or `android`
- `orderId`
- `transactionId`
- `platformOrderId`
- `receipt` or purchase token
- `productId`
- `idempotencyKey`

Response:

- `verificationStatus`: `pending`, `verified`, `failed`, `refunded`,
  `revoked`
- `orderStatus`
- `entitlements`
- `walletDelta`
- `membershipStatus`

Rules:

- Client purchase success is not enough. Server verification and entitlement
  response are source of truth.
- Use idempotency keys and platform transaction ids.
- Client state machine must tolerate pending verification and retry.

### Entitlement / Unlock

Future repository:

- `EntitlementRepository`

Future endpoints:

- `GET /entitlements`
- `GET /episodes/{episodeId}/access`
- `POST /entitlements/unlock`

Unlock request:

- `episodeId`, `dramaId`, `priceCoins`, `idempotencyKey`.

Response:

- `accessStatus`, `walletBalance`, `unlockedEpisodeIds`, `expiresAt`.

Player impact:

- Locked episode tap opens unlock/member sheet.
- Successful unlock refreshes access state and may retry playback source.

### Localization Fixed Bundle

Current state:

- `AppLocalizations` is local and hand-written.
- `docs/localization-and-home-data-architecture.md` records the remote bundle
  backlog.

Future endpoints:

- `GET /app/i18n/version`
  - Query: `locale`, `appVersion`, current local `version`.
- `GET /app/i18n/bundle`
  - Query: `locale`, `version`.

Response:

- `version`, `locale`, `checksum`, `messages`.

Cache:

- Persistent by locale/version/checksum.
- Fallback order: remote bundle -> local `AppLocalizations` -> English -> key.

### Content Localization

Policy:

- Content endpoints accept `locale`.
- Server returns localized titles, descriptions, tags, category names, episode
  titles, and content metadata.
- Client does not put drama content in fixed UI language bundle.

Fallback:

- Server should return fallback language metadata and indicate fallback locale.
- Client should display server-provided content without translating locally.

### Subtitle Tracks

Future source field:

```json
{
  "subtitleTracks": [
    {
      "language": "en",
      "label": "English",
      "url": "https://cdn.example.com/subs/en.vtt",
      "format": "vtt",
      "isDefault": true
    }
  ]
}
```

Policy:

- Select track matching current locale.
- If no match exists, use server default or no subtitle according to product
  policy.
- Subtitle fetch errors should not fail video playback.

## 5. Pagination Standard

Use cursor/token pagination at repository boundaries:

```dart
class ApiPage<T> {
  final List<T> items;
  final String? nextPageToken;
}
```

API endpoints may internally use offset/page/cursor, but data repositories must
map them to `nextPageToken` before application code sees them.

List APIs:

- Home feed
- Category/tag/search result
- For You feed
- Episode list if not returned in one payload
- My list
- Play history
- Wallet records
- Orders

## 6. Playback Interface Requirements

Playback source integration must remain aligned with
`docs/player-source-and-cdn-spec.md`.

Required behavior:

- Locked/unavailable/null source items never resolve, preload, prepare, or open.
- Playback source expiry is respected through `expiresAt`.
- Source refresh handles `403 source_expired` separately from entitlement
  `403`.
- `backupHlsUrls` are tried only through playback controller/repository policy,
  not in UI.
- `durationMs`, dimensions, aspect ratio, subtitles, preview sprite/VTT, preload
  policy, and cache policy are exposed to domain models.
- Progress get/save is non-blocking. For You cross-session progress restore
  remains disabled unless product confirms it.

## 7. Payment / IAP Interface Requirements

The client should separate UI package display, order creation, store purchase,
receipt verification, and entitlement refresh.

Suggested state mapping:

| Client state | Server / store dependency |
| --- | --- |
| package selected | local UI only |
| order creating | `POST /orders` |
| store purchase pending | App Store / Google Play SDK |
| receipt verifying | `POST /iap/verify` |
| verified | server verified receipt and issued entitlement/wallet delta |
| failed/cancelled | store or server failure |
| refunded/revoked | server notification or status query |

Rules:

- Never trust only the client-side purchase success.
- Every verification request uses `idempotencyKey`, `transactionId`, and
  platform order id.
- Wallet balance, membership status, and unlock access refresh from server after
  verification.
- Refund/revocation must remove or downgrade entitlement according to server
  response.

## 8. Data Cache Strategy

Recommended cache policy:

- Home categories: persistent or long memory cache with version.
- Home feed first page: short memory cache; optional stale-while-revalidate.
- Drama detail: short memory cache; invalidate after favorite/access changes.
- Episode list: short cache; invalidate after entitlement change.
- Playback source: no long-term cache; only keep until `expiresAt`.
- HLS playlist/segment preload: controlled by `PlayerPreloadConfig` and source
  `preloadPolicy`; no production local HLS cache yet.
- Wallet summary: short cache; refresh after order/unlock/membership changes.
- Orders/IAP: active order status must be fresh; historical orders can paginate.
- Membership/wallet entitlement: refresh on app foreground, purchase, restore,
  and account switch.
- Fixed localization bundle: persistent by version/checksum.
- Playback progress: local temp save plus eventual server sync.

## 9. Implementation Phases

Phase A: API skeleton without behavior switch

- Add DTO/mapper patterns per feature.
- Add remote data sources and repository implementations behind providers.
- Add token/header interceptors to `ApiClient`.
- Keep mocks as default.

Phase B: Home / detail / playback source behind feature flag

- Integrate `DramaRepository`, `PlayerFeedRepository`,
  `PlayerPlaybackSourceRepository`.
- Keep mock fallback and timing logs.
- Validate first-frame and feed errors on real devices.

Phase C: Auth / Profile / My list / history

- Auth/Profile remote skeletons are in place behind feature flags; secure token
  storage, refresh queue, and real session bootstrap remain deferred.
- Connect favorites and play history.
- Ensure logout clears feature caches and playback session state.

Phase D: Wallet / Store / Membership products and orders

- Connect product list and order creation.
- Keep mock purchase UI until store SDK and verification are ready.

Phase E: IAP verification and entitlement

- Add platform SDK integration.
- Verify receipts server-side.
- Refresh wallet/membership/unlock states from server only.

Phase F: API integration readiness

- Finalize baseUrl/env and remote switch policy.
- Connect unified `Device-Id`, `Lang`, `Platform`, `App-Version`, and token snapshot sources to
  `ApiRequestContext`.
- Add token storage skeleton and refresh queue boundaries.
- Define logout/delete cleanup entry for token, feature caches, and playback sessions.
- Keep all remote repositories disabled by default.

Phase F status:

- `AppConfig` supports dev/staging/prod and `API_BASE_URL` override.
- `ApiRequestContext` is composed by `apiRequestContextProvider` from `installIdProvider`,
  `apiLangProvider`, `apiPlatformProvider`, `apiAppVersionProvider`, and `AuthTokenStore` (A4).
- Remote DTO strict parsing via `JsonFieldParser` / `ApiMappingException` (A6); display fields
  fallback in mappers only.
- `AuthTokenStore` is an in-memory skeleton; secure storage remains deferred.
- `AuthRefreshCoordinator` establishes refresh in-flight dedupe; automatic 401 retry remains deferred.
- `SessionCleanupCoordinator` establishes the cleanup entry; feature cache and Player hooks remain deferred.
- All `USE_REMOTE_XXX_API` switches remain false by default.

Phase F review:

- Added boundary tests so token storage, refresh coordination, and session cleanup do not leak into UI,
  pages, app shell, or feature controllers.
- Confirmed refresh failures clear the in-flight marker, so later refresh attempts are not blocked.
- Confirmed cleanup remains a skeleton entry point and is not wired into current mock Auth / Account /
  Player flows yet.

Phase G: Remote localization and subtitles

- Add fixed bundle version/download/cache.
- Add content locale request propagation.
- Add playback subtitle track selection.

Phase H: Error, weak network, and release-device regression

- Full API error matrix.
- Offline/timeout retry tests.
- Real-device playback, payment, auth, and localization regression.

## 10. Risks And Prohibited Shortcuts

Risks:

- Backend field shapes may drift from domain models if DTO mapping is skipped.
- Payment state can become inconsistent if the client treats local store success
  as final.
- Playback source expiry can cause confusing player failures without refresh
  semantics.
- Startup and playback preload can waste data if server policy is ignored.
- Token refresh can race with parallel feature requests.

Prohibited shortcuts:

- UI must not create repositories, remote data sources, or `Dio`.
- Controllers must not parse JSON or inspect raw HTTP status.
- DTOs must not leak into presentation widgets.
- Mock models and remote DTOs must not be mixed into one type.
- Payment success must not be granted only from client-side SDK callbacks.
- Playback source must not be cached indefinitely.
- Entitlement failures must not be silently converted to generic media errors.
- Localization content must not be duplicated into fixed UI bundles.

## 11. Follow-Up Structure Notes

Current structure is broadly ready for API integration:

- Feature-first repositories already exist for auth, drama/home, player,
  my list, wallet, store, and membership.
- `core/network` already has `ApiClient`, `ApiRequestContext`,
  `ApiAuthPolicy`, `ApiException.businessCode`, and paging helper. Network
  Contract Phase B has aligned base headers and envelope handling with the
  service contract while keeping real token storage/refresh deferred.
- Player source/CDN requirements are already documented separately.

Recommended later cleanups before remote rollout:

- Add explicit remote data source and mapper folders as each feature integrates.
- Introduce `OrderRepository`, `IapRepository`, `EntitlementRepository`, and
  `LocalizationRepository` before implementing payment/localization.
- Consider a `ProfileRepository` only if profile fields no longer fit cleanly
  inside auth/session plus wallet/membership summaries.
- Keep startup preload and playback preload scopes separate when real playback
  source APIs arrive.
