# Global Overlay / Modal System Plan

> Status: **O1–O5 + O2.1 complete** (2026-05-17). Player unlock/recharge/payment-method, Auth login/login-required, and Store/Membership purchase confirmation use the global modal host. Player `Payment Method` uses `player.payment_method` with `stackOnCurrent` above the recharge drawer. Wallet has no blocking confirmation modal (restore → toast; auto unlock → in-page switch). O5 finalized queue/priority/dismiss/observer/runtime config; no Modal Ops / analytics / remote kill switch in this track.

## Why This Exists

The current app already has several cross-feature overlay flows:

- Player coin unlock sheet.
- Player recharge sheet.
- Player payment confirmation sheet（O2.1：`player.payment_method` AppModal + stackOnCurrent）.
- Membership purchase entry.
- Store confirmation and restore feedback.
- Login / auth prompts planned for later.
- Global toast.

Most of these are currently triggered near the feature that owns the UI. That is acceptable for the current mock release, but it has one structural weakness: a sheet can be hosted under the wrong navigator, stack, tab shell, or safe area. The known example is For You showing an unlock or recharge sheet that can be partially covered by the bottom tab.

The long-term goal is an app-level modal system that owns the host layer, safe-area behavior, request/result typing, queueing, priority, and dismissal policy. Feature code should request a modal intent and receive a typed result; it should not decide which navigator layer or root overlay should host the modal.

## Current Release Decision

For the current release:

- Player unlock/recharge uses the global root modal host because For You and bottom-tab layering can cover local sheets.
- Player `Payment Method` stacks on the recharge drawer via `FeatureAppModalRequest.stackOnCurrent` and `PaymentModalResult`, preserving the two-level UX without shrinking the recharge drawer.
- Store / Membership purchase confirmation uses the global root modal host (O4).
- Wallet has no blocking confirmation sheet in MVP; restore uses toast only (O4 no-op).
- Do not connect real IAP or real API as part of this modal migration.

当前已接入的弹窗、channel、payload/result 和使用方式见 [AppModal Supported Modals](app-modal-supported-modals.md)。

This document records the target design and migration plan for the first post-release architecture optimization round.

## Goals

- Provide one app-level entry point for business overlays.
- Prevent bottom tab, page stacks, Player fullscreen layers, or nested navigators from covering critical sheets.
- Support typed request/result flows.
- Support cancel, close, success, failure, and retry results.
- Support modal queue, priority, and mutual exclusion.
- Support back button and outside-tap policies.
- Support safe area and keyboard handling consistently.
- Support source context for diagnostics and analytics.
- Keep existing content widgets reusable.
- Keep feature tests easy by allowing fake modal services.

## Non-Goals

- Do not replace page-local dropdowns, menus, or tooltips.
- Do not turn every visual overlay into a global modal.
- Do not productionize HLS proxy/cache or change Player playback architecture.
- Do not connect real IAP or real API as part of this modal system.
- Do not make business state live inside the modal host.

## What Should Use The Global Modal System

The following flows should eventually use `AppModalService` or its equivalent:

- Login prompt.
- Coin unlock confirmation.
- Recharge sheet.
- Payment confirmation sheet.
- Membership purchase prompt.
- Store purchase confirmation.
- Wallet restore / confirm dialog.
- Error confirmation dialog that blocks progress.
- Risk-control prompt.
- Force upgrade / maintenance prompt.
- Activity or campaign popup.
- Permission education prompt if it must cross route boundaries.

## What Should Not Use It

The following should usually stay local:

- Simple dropdowns.
- Inline menus.
- Local tooltip overlays.
- A page-only bottom sheet that cannot be covered by app chrome and does not need a result.
- Pure visual affordances inside Player, such as pause feedback.

Toast can remain in `AppToastService`. The design should decide whether toast shares the same root overlay host internally, but feature code should continue using the toast service for transient messages.

## Proposed Architecture

```text
DramaClientApp
  └─ AppRootOverlayHost
       ├─ GoRouter / Shell routes / bottom tab
       ├─ AppModalHost
       └─ AppToastHost (or BotToast integration)

Feature code
  └─ AppModalService
       ├─ showLogin(...)
       ├─ showCoinUnlock(...)
       ├─ showRecharge(...)
       ├─ showPaymentConfirm(...)
       ├─ showConfirm(...)
       └─ showBlockingUpgrade(...)
```

### Core Concepts

`AppModalService`
: The only business-facing API for global modals. Feature code calls this service and awaits typed results.

`AppModalHost`
: The root-level presenter. It decides which modal is visible and applies safe-area, keyboard, back-button, queue, and priority policy.

`AppModalRequest`
: A typed request containing modal type, source, request id, payload, priority, dismiss policy, and analytics metadata.

`AppModalResult`
: A typed result such as success, cancel, dismissed, failed, retry, or specific flow result like `PaymentResult.success`.

`AppModalQueue`
: A coordinator that prevents multiple critical modals from competing. It should support dedupe and exclusive groups.

`AppModalSource`
: A lightweight source descriptor such as `player`, `forYou`, `store`, `wallet`, `auth`, or `system`.

## Suggested API Shape

The final names can change, but the API should be typed and explicit:

```dart
abstract interface class AppModalService {
  Future<LoginResult> showLogin(LoginModalRequest request);

  Future<CoinUnlockResult> showCoinUnlock(
    CoinUnlockModalRequest request,
  );

  Future<RechargeResult> showRecharge(
    RechargeModalRequest request,
  );

  Future<PaymentResult> showPaymentConfirm(
    PaymentConfirmModalRequest request,
  );

  Future<ConfirmResult> showConfirm(
    ConfirmModalRequest request,
  );
}
```

Business code should not pass raw callbacks into modal content. The service should return a typed result. When callbacks are unavoidable for legacy migration, wrap them behind a typed result adapter.

## Dismiss And Back Policy

Every modal request must declare how it can close:

- `barrierDismissible`: outside tap closes or not.
- `backButtonPolicy`: close, ignore, or confirm.
- `requiresExplicitChoice`: true for payment, force upgrade, and destructive actions.
- `cancelResult`: which typed result is emitted if dismissed.

Payment and unlock flows must distinguish:

- User cancelled.
- User closed the sheet.
- Payment failed.
- Payment succeeded.
- Entitlement refresh succeeded.
- Entitlement refresh failed.

## Queue And Priority

The initial implementation can keep the queue simple:

- Only one critical business modal visible at a time.
- Toast remains separate and non-blocking.
- Higher priority system modals, such as force upgrade, can preempt lower-priority modals.
- Duplicate requests with the same request id should be ignored or joined.

Recommended priority order:

1. Force upgrade / maintenance.
2. Auth/session expired.
3. Payment confirmation.
4. Unlock/recharge/membership.
5. Generic confirm.
6. Campaign/activity.

## Player Integration

Player should not directly own root modal presentation. It should emit modal intent and wait for typed result.

Current Player pieces to migrate:

- `PlayerCoinUnlockSheet`
- `PlayerRechargeUnlockSheet`
- Player payment confirmation content
- `PlayerOverlayOrchestrator`
- `PlayerFeedEngine`

Target behavior:

- `PlayerFeedEngine` decides that an unlock/recharge/payment intent is needed.
- `AppModalService` presents the modal above the root shell, not inside a tab body.
- The result returns to Player flow:
  - coin unlock success
  - recharge success
  - payment cancelled
  - membership activated
  - user dismissed

Existing sheet content should be reused as modal content widgets. The migration should avoid redoing UI.

## Relationship With AppToastService

`AppToastService` is already the correct business-facing entry point for transient messages. It should remain the only toast API.

The future modal host can share root overlay infrastructure with toast internally, but feature code should not use a generic overlay object to show toast. Keep:

- `appToastProvider` for toast.
- `appModalServiceProvider` for modal flows.

## README And Documentation Requirements

When implementation starts, update:

- `README.md` with a clear `App Runtime / Global Overlay / Modal System` entry.
- This document with implementation status.
- `docs/app-runtime-system.md` if runtime config controls modal behavior.
- `docs/player-feed-engine-refactor-plan.md` if Player modal orchestration changes.

README should explain:

- What the global modal system is.
- Which business overlays must use it.
- Why feature code should not call `showModalBottomSheet` directly for global business flows.
- Where to find usage examples.

## Migration Plan

### Phase O1: Design And Skeleton — **Done**

- [x] `AppModalService` interface + `AppModalServiceImpl`
- [x] Typed request/result models (`ConfirmModalRequest`, `ConfirmResult`, reserved `LoginModalResult` / `PaymentModalResult` / …)
- [x] Root-level `AppModalHost` in `DramaClientApp` builder + `appRootNavigatorKey`
- [x] `RecordingAppModalService` for tests (`test/helpers/recording_app_modal_service.dart`)
- [x] `AppModalQueue` skeleton + serial present in `AppModalController`
- [x] `test/architecture/modal_boundary_test.dart` (core/modal ↔ features, toast boundary, legacy sheet whitelist)
- [x] Player business flow migration — O2
- [x] Store / Membership purchase confirmation — O4
- [x] Wallet — O4 no-op (no blocking confirmation modal)

### Phase O2: Player Unlock / Recharge — Done

- Player coin unlock and recharge route through `AppModalService`.
- Player `Payment Method` uses AppModal `stackOnCurrent` above the recharge sheet (O2.1 Done).
- Existing Player sheet widgets are reused as content inside root-hosted modal sheets.
- `AppModalSource.player` can be dismissed as a group when Player route is disposed.
- Player detail/share/speed sheets remain local because they are page-local UI, not cross-tab blocking business flows.
- Unlock/payment behavior is unchanged: coin enough -> Play sheet; coin insufficient -> recharge -> payment -> Play; membership purchase -> unlock/play according to existing mock flow.

### Phase O3: Auth And Login — Done

- Channel `auth.login` via `AuthAppModalPresenter` + `AuthLoginModalSheet` (reuses `AuthLoginModalContent`).
- Typed `AuthLoginModalPayload` / `AuthLoginModalResult` (success / cancelled / dismissed / failed); success carries `provider`, `AuthUser`, `accountLinked`.
- `AuthModalCoordinator`: `showLogin`, `showLoginRequired(reason)`, `showSessionExpiredLogin`; Profile 入口走 modal 而非 push `/auth`.
- Mock login stays on `AuthController` → `AuthRepository` (modal does not write `AuthTokenStore`).
- Account link prep: mock `login` preserves `guestId` from prior guest session; real API will send `guestId` / `deviceId` / guest token in login body.
- Session policy: **refresh failed → token cleanup → guest bootstrap**; login modal **not** auto-shown at startup. Use `showSessionExpiredLogin` on user action only.
- A7 `featureSessionCleanup` calls `dismissAllBlockingBusinessModals` (player/store/membership/auth) and drains the modal queue without presenting the next item.
- Deferred: real OAuth SDK, real login API, auto-login on 401 interceptor, My List / Wallet / Store restore login gates (call `showLoginRequired` when needed).
- `RoutePaths.auth` full-page route kept for deep links and widget tests.

### Phase O4: Store / Membership / Wallet — Done

- Store purchase confirmation (`store.purchase_confirmation` / `AppModalSource.store`).
- Membership purchase confirmation (`membership.purchase_confirmation` / `AppModalSource.membership`).
- Wallet: **no-op** — restore uses `AppToastService.info`; auto unlock is an in-page switch (no `showModalBottomSheet`).
- Presenters reuse `StoreConfirmationSheet` / `MembershipConfirmationSheet`; controllers still own mock purchase / `hideConfirmation`.
- Page dispose calls `dismissForSource` for store/membership source.

### Phase O5: Control Center Finalization — Done

- **Queue**: `AppModalQueue` inserts by priority (desc), then `createdAt` (asc); current modal is never preempted (`allowPreemption` default false).
- **Dismiss**: `standard` / `blocking` (no barrier, back OK) / `nonDismissible` & `critical` (explicit action or dismiss API only); `app_modal_dismiss.dart` shared by confirm + root sheets.
- **Diagnostics**: `AppModalObserver` + `RecordingAppModalObserver`; events queued / presented / completed / dismissed / cancelled / failedToPresent / queueRejected; gated by `enableModalDiagnostics`.
- **Runtime**: `AppModalRuntimeConfig` (`enableGlobalModalSystem`, `maxQueueLength`, …); feature flag keys reserved in `RuntimeFeatureFlagKeys`; no remote/analytics in O5.
- **Reject**: `AppModalRejectedResult` (queue full / system disabled); `AppModalPresentFailedResult` when presenter missing — queue continues.
- **Local whitelist** (architecture test): `player_page` local sheets; `account_page` delete dialog.
- **Defer (Modal Ops track)**: campaign popups, force upgrade, risk prompts, analytics, remote kill switch.

## Testing Plan

- Feature code can use fake `AppModalService` in widget tests.
- For You unlock/recharge sheet is never covered by bottom tab.
- Player fullscreen and single drama routes show modals at the correct layer.
- Payment confirmation closes back to recharge when cancelled.
- Result typing is correct for success, cancel, dismiss, and failure.
- Back button policy works on Android.
- Queue prevents multiple critical modals from stacking.
- Duplicate request ids do not show duplicate sheets.
- Auth/login modal can be shown from any route.
- Feature modules do not directly import third-party modal packages.
- Global business sheets do not call `showModalBottomSheet` directly from feature pages after migration.

## Architecture Tests To Add

After Phase O1/O2:

- Features cannot import third-party modal packages directly.
- Player unlock/recharge must go through `AppModalService`.
- O2.1 Done: Player `Payment Method` uses `player.payment_method` + `PaymentModalResult` + `stackOnCurrent`.
- Modal request/result models are not raw `bool` or `String`.
- Global business modal usage does not bypass the service from presentation pages.

## Release Freeze Policy

During the current release QA:

- Do not start this migration.
- Only apply a minimal For You sheet coverage fix if QA marks the issue as blocking.
- Treat this document as the queued architecture plan for the next development cycle.
