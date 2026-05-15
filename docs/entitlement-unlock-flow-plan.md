# Entitlement Unlock Flow MVP Plan

## Scope

This document is a read-only architecture assessment plus mock data plan for the first short-drama unlock loop. It does not require changing player, UI, payment, or networking code in this round.

The MVP should implement:

- Playback completion automatically attempts the next episode.
- Before playback starts, the app asks entitlement for a decision.
- Free episodes play directly.
- Membership episodes play directly for members and send non-members to membership.
- Coin episodes check balance and auto-unlock preference.
- Enough coins plus auto unlock on deducts coins once, records the unlock, and plays.
- Enough coins plus auto unlock off shows a coin unlock sheet.
- Insufficient coins shows a recharge sheet.
- Closing unlock/recharge sheets returns to the pending locked episode.
- Returning from recharge or membership continues the pending unlock decision.
- Coin deduction success plays the pending episode.

Deferred but reserved by feature config:

- Ad unlock.
- Whole-drama purchase.
- Coupon unlock.
- Limited-free windows.
- Cross-device entitlement sync.
- Real payment.
- Real backend.
- Real IAP receipt validation.

## Current Code Assessment

### PlayerPlaybackController

`PlayerPlaybackController` remains the media-session orchestration boundary. It owns source resolve, open/play/pause, seek, progress restore/save, HLS preload, prepared session window, timing trace, hidden/dispose release, and playback errors.

Current behavior relevant to entitlement:

- Locked episodes are blocked before source resolve/open, so no HLS preload or session prepare happens for locked content.
- Unavailable and null-source episodes are separated from locked episodes and also avoid source resolve/open.
- The controller already distinguishes playback error kinds: `recoverableNetwork`, `sourceResolve`, `mediaFatal`, and `unknown`.
- The controller should not learn about membership, coins, prices, or unlock dialogs. It should continue to receive a `PlayerFeedItem?` only after entitlement says playback is allowed.

Assessment:

- Good boundary for media lifecycle.
- Do not add entitlement branching here.
- Keep `blocked` for "not playable yet" but let entitlement decide why it is blocked.

### PlayerFeedController

`PlayerFeedController` owns feed loading, current index, `goNext`, and episode selection. It does not resolve sources or decide paid access.

Current behavior relevant to entitlement:

- It can switch current index before playback begins.
- `selectEpisode` can replace the current item episode if the selected episode is not already in feed.
- It currently treats `PlayerEpisode.isLocked` as a UI/paywall signal via `PlayerUiController`.

Assessment:

- Good place to hold the visible/pending episode position.
- It should not decide member/coin access.
- It can still switch to the next item before showing an unlock sheet, so the user sees the pending locked episode page.

### PlayerUiController and Paywall

`PlayerUiController` owns UI-only state: episode number, UI play intent, and `PlayerPaywallState`.

Current paywall states:

- `hidden`
- `unlock`
- `memberUnlock`

Current behavior:

- Locked episodes show the generic unlock overlay.
- Unavailable episodes do not show paywall and do not start playback.
- The unlock sheet currently simulates unlock and then calls `playItem` on the current item.

Assessment:

- Existing overlay can be reused for the "pending locked page" dark overlay and the membership CTA label.
- The generic `unlock` state is too coarse for coin-price, insufficient-balance, auto-unlock-off, and route-return continuation.
- Add entitlement-specific UI state either by expanding `PlayerPaywallState` or by introducing a small `PlayerPendingUnlockState` that `PlayerPage` maps to overlay/sheets.

### PlayerPage Auto Next and Locked Logic

`PlayerPage` listens for `playbackState.hasEnded` and calls `_advanceToNextFromCompletion`. The page animates to the next page, then updates `PlayerFeedController.currentIndex`. The current item listener then calls `playItem(next)` and `preloadAround`.

Current behavior:

- Completed playback auto-advances to the next episode.
- If the next episode is locked, the page reaches the next episode and shows paywall.
- Completed playback is ignored while a sheet is open, while seeking, while paywall is visible, and on the last item.

Assessment:

- The "first switch to next locked page, then show unlock UI" behavior is already close to the desired UX.
- The key change should be between feed current-item change and `playItem(next)`: call entitlement decision first. Only call `playItem` for `allowPlay` or successful unlock.
- The page should keep a pending unlock target so route returns from Store/Membership can re-run the same decision.

### StoreController

`StoreController` loads coin/VIP packages and tracks mock purchase confirmation state.

Current behavior:

- Mock purchase is only a UI state machine: idle, processing, success, cancelled.
- Existing comments correctly warn that mock success should not directly mutate wallet balance.
- Confirmation uses a generation and package id to avoid stale completion.

Assessment:

- Store should not own entitlement balance.
- For MVP, after mock purchase success, Store should notify the shared entitlement mock state to add coins, then the player can continue pending flow.
- Keep Store package state separate from wallet/entitlement state.

### MembershipController

`MembershipController` loads membership plans and tracks mock membership purchase state.

Current behavior:

- Mock purchase success does not directly change `isActive`.
- Existing comments correctly say membership activation should come from entitlement refresh.
- Confirmation uses generation and plan id to avoid stale completion.

Assessment:

- Membership should not be the source of truth for playable membership access.
- For MVP, mock membership success should call entitlement shared state to mark `isMember = true`, then the player can continue pending flow.

### WalletController

`WalletController` loads wallet balance, bonus, auto-unlock preference, and record lists.

Current behavior:

- Balance and records are repository-driven.
- Auto unlock is local UI state with `autoUnlockTouched` protection on reload.
- Mock reward claiming does not directly change balance.

Assessment:

- Auto unlock preference should become part of `UserEntitlementState`.
- Wallet can continue showing wallet-specific data, but its toggle should write to the shared entitlement repository/controller rather than being a separate independent source.
- For first implementation, a shared mock state provider can back both Wallet and Entitlement, with Wallet still mapping it into wallet UI state.

### Profile and Auth

`AuthController` is the global login/session source. Profile reads auth/profile-like state elsewhere, but entitlement should not infer membership from profile UI labels.

Assessment:

- `UserEntitlementState` should include or derive `isGuest`/`userId` from Auth.
- Guest should be modeled explicitly in entitlement tests. The MVP flow can treat guest like non-member unless product wants login-first for paid unlock.

### Routes

Relevant routes exist:

- `RoutePaths.membership`
- `RoutePaths.store`
- `RoutePaths.wallet`

Assessment:

- Membership and Store can be pushed from the pending unlock flow.
- Return handling should not depend on route query strings for MVP. Keep pending unlock state in entitlement/player UI controller keyed by player `sessionKey`.

### Existing Test Coverage

Covered today:

- Player blocks locked episodes without source resolve/open.
- Player does not resolve/preload locked, unavailable, or null-source items.
- Player page auto-advances on completion.
- Player page shows paywall when auto-advance reaches locked episode.
- Player page ignores completion while sheet/paywall/seek blocks are active.
- Player UI state keeps paywall isolated by session.
- Store mock purchase processing/success/cancel/stale close.
- Membership mock purchase processing/success/cancel/stale close.
- Wallet load, auto-unlock toggle, reload preservation, and records.
- App-level navigation to membership/store/wallet paths.

Missing for entitlement MVP:

- Decision matrix for free/member/coins/unavailable/locked.
- Pending unlock target retained after closing sheet.
- Return from membership or store re-runs pending decision.
- Auto-unlock coin deduction idempotency.
- Already unlocked episode does not deduct again.
- Guest versus logged-in non-member behavior.
- Mock deduction failure path.

## Recommended Feature-First Architecture

Add:

```text
lib/features/entitlement/
  domain/
    entitlement_feature_config.dart
    episode_access_decision.dart
    episode_unlock_type.dart
    entitlement_repository.dart
    user_entitlement_state.dart
  data/
    mock_entitlement_repository.dart
    entitlement_repository_provider.dart
  application/
    entitlement_controller.dart
```

Recommended names:

- `EpisodeUnlockType`: good name. It describes content policy, not user state.
- `EpisodeAccessDecision`: good name. It describes the result Player consumes.
- `UserEntitlementState`: good name. It should be the user-level source of truth for membership, coins, auto unlock, and unlocked episodes.
- `EntitlementFeatureConfig`: good name. Keep it in entitlement domain or data config provider.
- `EntitlementRepository`: good name for read/write entitlement operations.
- `MockEntitlementRepository`: good name.
- `EntitlementController`: good first controller.
- `UnlockController`: defer for MVP. Add only if `EntitlementController` grows separate long-running action state for multiple unlock surfaces.

### Domain Model

```dart
enum EpisodeUnlockType {
  free,
  membership,
  coins,
}

enum EpisodeAccessDecisionType {
  allowPlay,
  goMembership,
  showCoinUnlockDialog,
  showRechargeDialog,
  autoUnlockAndPlay,
  waitUnlock,
}
```

`EpisodeAccessDecision` should include:

- `type`
- `dramaId`
- `episodeId`
- `itemId`
- `unlockType`
- `price`
- `balance`
- `reason`
- optional `operationId` for idempotent auto unlock attempts

`UserEntitlementState` should include:

- `isGuest`
- `isMember`
- `coinBalance`
- `bonusBalance` if bonus has different future rules, otherwise defer
- `autoUnlockEnabled`
- `unlockedEpisodeIds`
- `pendingUnlock`
- `inFlightUnlockEpisodeId`
- `lastUnlockError`

`EntitlementFeatureConfig` should include the requested switches, all default false:

- `enableAdUnlock`
- `enableWholeDramaPurchase`
- `enableCouponUnlock`
- `enableLimitedFree`
- `enableServerDrivenEntitlement`
- `enableCrossDeviceEntitlementSync`
- `enableEntitlementDebugPanel`
- `enableAutoUnlockPromptRemember`

Add one MVP switch:

- `enableCoinUnlock = true`

This makes the first enabled scope explicit while future knobs remain off.

### Repository Boundary

`EntitlementRepository` should be the only writer for:

- membership active flag in mock mode
- coin balance in mock mode
- unlocked episode ids
- auto-unlock preference
- coin deduction operation result

Suggested methods:

```dart
Future<UserEntitlementState> fetchState();
Future<void> setAutoUnlockEnabled(bool enabled);
Future<UserEntitlementState> grantMockMembership({required String source});
Future<UserEntitlementState> grantMockCoins({
  required int amount,
  required String source,
});
Future<UnlockEpisodeResult> unlockEpisodeWithCoins({
  required String dramaId,
  required String episodeId,
  required int price,
  required String operationId,
});
```

The repository should own idempotency by `operationId` plus episode id. If the same operation retries, it returns the previous result without a second deduction.

### Controller Boundary

`EntitlementController` should:

- Load user entitlement state.
- Decide access for a `PlayerFeedItem`.
- Store pending unlock target.
- Execute coin unlock.
- Consume Store/Membership success notifications.
- Expose action status for UI: idle, deciding, unlocking, failed.

Do not put `PageController`, `PlayerPlaybackController`, or route navigation inside entitlement. PlayerPage remains the integrator.

Defer `UnlockController` unless:

- unlock actions need separate provider family by `sessionKey`
- multiple entry points can unlock different episodes simultaneously
- purchase/order verification introduces a separate long-running workflow

For first round, keep one `EntitlementController` plus a small `PendingUnlock` model.

## Mock Data Design

### User Scenarios

Create named fixtures in `MockEntitlementRepository`:

| Scenario | Auth | Member | Coins | Auto unlock | Unlocked episodes | Failure |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `guest` | guest | false | 0 | false | empty | none |
| `loggedInNonMemberEnoughCoinsAutoOn` | logged in | false | 400 | true | `found-you:ep-4` | none |
| `loggedInNonMemberEnoughCoinsAutoOff` | logged in | false | 400 | false | empty | none |
| `loggedInNonMemberLowCoins` | logged in | false | 20 | false | empty | none |
| `loggedInMember` | logged in | true | 60 | true | empty | none |
| `partialUnlocks` | logged in | false | 200 | true | `found-you:ep-4`, `found-you:ep-5` | none |
| `deductFailsOnce` | logged in | false | 400 | true | empty | next deduction fails |
| `afterMockMembershipPurchase` | logged in | true | previous | previous | unchanged | none |
| `afterMockRecharge` | logged in | previous | +300 or +2000 | previous | unchanged | none |

### Drama and Episode Rules

Represent entitlement metadata separately from `PlayerEpisode.isLocked`:

| Drama | Rule | Episodes |
| --- | --- | --- |
| `found-you` | first 3 free, episode 4+ coin unlock | ep 1-3 free, ep 4 price 30, ep 5 price 50, ep 6+ price 80 |
| `heart-thief` | membership exclusive | all available episodes membership |
| `reborn-love` | free drama | all available episodes free |
| `secret-vow` | mixed coin prices | ep 1-3 free, ep 4-10 30, ep 11-20 50, ep 21+ 80 |
| `asian-reunion` | contains unavailable fixture | ep 9 unavailable keeps player unavailable |

Keep existing `PlayerEpisode.isUnavailable` for unavailable/down/region blocked content. Do not model it as entitlement. Keep existing `isLocked` only as a presentation/backward-compatibility hint until entitlement metadata drives UI; long term, replace generic locked with `unlockType`.

### Episode Price Fixtures

Use stable IDs:

```text
found-you:ep-4  -> coins, 30
found-you:ep-5  -> coins, 50
found-you:ep-6  -> coins, 80
secret-vow:ep-4 -> coins, 30
secret-vow:ep-11 -> coins, 50
secret-vow:ep-21 -> coins, 80
heart-thief:ep-1 -> membership
reborn-love:ep-1 -> free
asian-reunion:ep-9 -> unavailable through PlayerEpisode.isAvailable=false
```

### Playback Path Matrix

| Path | Setup | Expected decision | Side effect |
| --- | --- | --- | --- |
| Auto next to free | ep 1 completed, ep 2 free | `allowPlay` | no balance change |
| Auto next to membership, member | member true | `allowPlay` | no balance change |
| Auto next to membership, non-member | member false | `goMembership` | pending target saved |
| Auto next to coins, enough, auto on | coins >= price, auto unlock true | `autoUnlockAndPlay` | deduct once, add unlocked episode |
| Auto next to coins, enough, auto off | coins >= price, auto unlock false | `showCoinUnlockDialog` | pending target saved |
| Auto next to coins, low balance | coins < price | `showRechargeDialog` | pending target saved |
| Manual locked episode | user taps locked episode | same decision matrix | current page becomes pending target |
| Close unlock dialog | pending target exists | `waitUnlock` | stay on pending page |
| Recharge return | coin balance increased | re-decide pending target | play if now enough and user confirms/auto on |
| Membership return | member true | re-decide pending target | play membership/free target |
| Already unlocked | unlocked id exists | `allowPlay` | no additional deduction |
| Deduct failure | fail next deduction | `showCoinUnlockDialog` or failed action | no unlock id added |

## Player Integration

Player should not directly inspect membership, coin balance, price, or unlocked ids.

Recommended flow on current item change:

1. `PlayerPage` receives new `feedState.currentItem`.
2. `PlayerPage` updates visible episode state, so the user sees the target page.
3. `PlayerPage` calls `entitlementController.decide(item)`.
4. If decision is `allowPlay`, hide paywall and call `playbackController.playItem(item)`.
5. If decision is `autoUnlockAndPlay`, call `unlockWithCoins(decision)`; on success call `playItem(item)`.
6. If decision is `goMembership`, show membership paywall/CTA and keep pending target.
7. If decision is `showCoinUnlockDialog`, show coin unlock sheet and keep pending target.
8. If decision is `showRechargeDialog`, show recharge sheet and keep pending target.
9. If decision is `waitUnlock`, keep the locked page visible and do not call `playItem`.

### Should Auto Next Switch First?

Yes. The current auto-next behavior should switch to the next episode page first, then run entitlement and show the relevant sheet/overlay. This matches the requested "close dialog returns to pending unlock page" behavior and avoids leaving the user visually on the previous completed episode while asking to unlock the next one.

### Pending Locked Page

Use existing player page composition:

- Keep the target episode as `feedState.currentItem`.
- Do not pass a video controller for denied decisions.
- Show the poster/chrome with an overlay.
- Existing `PlayerPaywallOverlay` can be reused for membership CTA and generic locked-page CTA.

Needed additions:

- Coin unlock sheet with price, current balance, auto-unlock toggle hint, and confirm.
- Recharge sheet or Store route entry for insufficient balance.
- Pending entitlement state that survives sheet close and route return.

### Locked, Unavailable, and Entitlement Types

Separate meanings:

- `unavailable`: content cannot be played at all. Keep current unavailable overlay; do not show unlock.
- `free`: entitlement allows immediate playback.
- `membership`: user can play if member; otherwise go membership.
- `coins`: user can play if already unlocked or after successful coin unlock.
- legacy `isLocked`: use only as a temporary presentation hint. Entitlement metadata should be the source for paid type and price.

### Deduction Idempotency

Auto unlock must guard at three layers:

- Controller layer: ignore duplicate unlock requests while `inFlightUnlockEpisodeId == targetEpisodeId`.
- Repository layer: require an `operationId` based on `sessionKey:itemId:attemptCounter` and return the previous result for duplicate operation ids.
- State layer: if `unlockedEpisodeIds` already contains target, return `allowPlay` without deduction.

## Store, Membership, and Wallet Linkage

### Store

On Store mock purchase success:

1. `StoreController` keeps its existing purchase status behavior.
2. A page-level listener or coordinator calls `entitlementController.grantMockCoins(amount, source: packageId)`.
3. If the player has a pending unlock target, re-run `continuePendingUnlock()`.

Do not let Store own or directly mutate wallet UI state.

### Membership

On Membership mock purchase success:

1. `MembershipController` keeps its existing purchase status behavior.
2. A page-level listener or coordinator calls `entitlementController.grantMockMembership(source: planId)`.
3. If the player has a pending membership target, re-run `continuePendingUnlock()`.

Do not infer membership playable access from `MembershipState.purchaseStatus` alone.

### Wallet

Wallet auto unlock should be backed by entitlement state:

- `WalletController.setAutoUnlockNextEpisode` writes to `EntitlementRepository.setAutoUnlockEnabled`.
- Wallet load maps `UserEntitlementState.autoUnlockEnabled` into wallet UI state.
- For MVP, this can be a shared mock state provider to avoid wiring a backend.

### Shared Mock State Provider

First phase should use a shared in-memory mock store:

```text
entitlementMockStoreProvider
  - isMember
  - coinBalance
  - autoUnlockEnabled
  - unlockedEpisodeIds
  - failNextCoinDeduction
  - operationResultsById
```

`MockEntitlementRepository`, Wallet mock, Store success bridge, and Membership success bridge can all use this provider. This prevents Store, Membership, Wallet, and Player from each carrying a separate fake copy of entitlement truth.

## State Machine

Recommended unlock flow states:

```text
idle
  -> deciding(target)
  -> allowed(target)
  -> pendingMembership(target)
  -> pendingCoinConfirm(target)
  -> pendingRecharge(target)
  -> unlocking(target, operationId)
  -> unlocked(target)
  -> failed(target, error)
```

Rules:

- `allowed` immediately calls playback and returns to idle.
- `pending*` states keep the target episode visible and do not call playback.
- Closing a sheet moves to `waitUnlock`/pending page, not previous episode.
- Returning from Store/Membership re-enters `deciding(target)`.
- `unlocking` ignores duplicate requests for the same target.
- `unlocked` adds episode id before playback starts.

## Test Plan

### Entitlement Unit Tests

- Free episode allows guest/member/non-member.
- Membership episode allows member.
- Membership episode sends non-member to membership.
- Coin episode already unlocked allows play and does not deduct.
- Coin episode enough balance auto on deducts once and allows play.
- Coin episode enough balance auto off returns coin unlock dialog.
- Coin episode insufficient balance returns recharge dialog.
- Deduct failure does not add unlocked episode and keeps pending target.
- Feature config future switches default false.

### Player Integration Tests

- Completion to free episode plays next.
- Completion to membership episode as non-member switches page and shows membership CTA.
- Completion to coin episode enough auto on deducts and plays.
- Completion to coin episode enough auto off switches page and shows coin sheet.
- Completion to coin episode low balance switches page and shows recharge sheet.
- Manual locked/coin episode uses same decision path as auto next.
- Closing unlock/recharge sheet leaves target episode visible.
- Route return from Store/Membership continues pending unlock.
- Unavailable episode still shows unavailable, not entitlement sheet.

### Store/Membership/Wallet Tests

- Store mock purchase success grants mock coins via entitlement state.
- Membership mock purchase success grants membership via entitlement state.
- Wallet auto unlock toggle updates entitlement state.
- Wallet reload does not overwrite local toggle before mock repository confirms.
- Shared state prevents divergent balances between Store/Wallet/Entitlement.

## Defer

- Real backend entitlement API.
- Real payment and IAP receipt validation.
- Server-driven source authorization.
- Multi-device sync.
- Ad unlock.
- Whole-drama purchase.
- Coupon unlock.
- Limited-free windows.
- Entitlement debug panel.
- Persistent local entitlement cache.
- Complex bonus-versus-coin spend ordering beyond recording the field.

## Conclusions

### Should We Add Entitlement Feature?

Yes. Add `lib/features/entitlement`. The current Player, Store, Membership, and Wallet boundaries are intentionally separate, and entitlement is the missing cross-feature business decision layer. Putting membership/coin branching into Player would couple media lifecycle to commerce state.

### Split EntitlementController and UnlockController?

Not in the first round. Start with `EntitlementController` plus repository methods for decision and unlock. Add `UnlockController` later only if concurrent unlock surfaces or real order verification make action state large enough to justify a split.

### Existing Paywall Reuse

Reuse:

- Existing locked-page overlay container.
- Existing membership CTA label path for `goMembership`.
- Existing route paths to Membership and Store.

Do not reuse as-is:

- Generic `PlayerUnlockSheet` for priced coin unlock. It lacks price, balance, auto-unlock, deduction failure, and recharge affordances.
- `PlayerPaywallState.unlock` as the only paid state. It needs entitlement-specific detail or a companion pending unlock model.

### Needed Small Refactors

- Add entitlement metadata separate from `PlayerEpisode.isLocked`.
- Change `PlayerPage` current-item listener to call entitlement decision before `playItem`.
- Add pending unlock state keyed by player `sessionKey`.
- Wire Store/Membership mock success to shared entitlement state.
- Make Wallet auto unlock read/write entitlement state.
- Keep `PlayerPlaybackController` free of membership/coin logic.

### Suggested Implementation Steps

1. Add entitlement domain/data/application with mock repository and unit tests.
2. Add mock entitlement fixtures and map player content episodes to unlock metadata.
3. Integrate PlayerPage decision flow without changing media controller internals.
4. Add coin unlock/recharge sheet states and pending unlock continuation.
5. Bridge Store/Membership/Wallet mock success/toggle into shared entitlement state.
6. Add integration/widget tests for auto next and manual locked selection paths.
