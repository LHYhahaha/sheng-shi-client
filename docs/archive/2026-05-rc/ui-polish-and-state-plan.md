# UI Polish and State Plan

This plan covers polish and state completion for the existing UI MVP screens.
It must not be used to add new product pages that are not present in Figma.

## Goals

- Keep the current Figma-approved visual structure.
- Polish spacing, typography, colors, safe areas, and scroll behavior on existing screens.
- Complete basic loading, empty, error, disabled, and mock success states where they are missing.
- Keep feature-first boundaries clear while polishing UI.

## Scope

Only the current implemented screens are in scope:

- Home
- For You
- Player
- My list
- Profile
- Login
- Account
- Store / Recharge
- Membership
- Wallet
- Transaction history
- Consumption history
- Record Coins
- Language

## Out Of Scope

- No new independent page unless it already exists in Figma and is explicitly approved.
- No real backend integration.
- No real Google or Facebook SDK integration.
- No real payment SDK or IAP state machine.
- No broad refactor.
- No redesign of already accepted visual structure.

## Phase 1: Visual And Interaction Audit

Audit existing screens before changing code. For each screen, record:

- Figma alignment issues: spacing, typography, color, radius, image position, asset usage.
- Interaction issues: back behavior, safe area, bottom navigation, sheet height, scroll feel, tap target.
- State issues: missing loading, empty, error, disabled, or confirmation states.
- Suggested priority: fix now or defer.

Suggested batches:

1. Home, For You, Player, My list.
2. Profile, Login, Account, Language.
3. Store, Membership, Wallet, wallet record pages.

## Phase 2: State Completion

Add only lightweight MVP states using existing mock repositories and controllers.

- Home: loading, error, empty.
- My list: collection empty, play list empty, after-delete empty.
- Store: purchase loading, mock success, mock cancel.
- Membership: purchase loading, mock success, mock cancel.
- Wallet: no-record empty, loading, error.
- Auth: login loading, mock failure, logout/delete loading.
- Player: locked episode, share sheet, episode sheet, about sheet, empty or unavailable episode states.

## Phase 3: Code Quality Sweep

Keep changes local and small:

- Route navigation must use `RoutePaths` and `RouteNames`.
- Business mock data must stay in `data` or `application`, not widgets.
- Complex state must live in application controllers, not page widgets.
- Repeated UI that appears across screens can move to `shared/widgets`.
- Repeated colors, radii, and spacing can move to `shared/theme`.
- Figma-specific one-off values may stay local when they are not reused.

## Review Requirements

Every implementation batch must be reviewed with:

- P0: must fix before continuing.
- P1: should fix in the current polishing phase.
- P2: can defer.

Each batch must pass:

```bash
dart format lib test
flutter analyze
flutter test
```

## Completion Criteria

- No current route points to placeholder UI.
- Existing screens keep their accepted visual structure.
- Key mock states are visible and testable.
- No Figma-missing pages are added.
- `flutter analyze` passes.
- `flutter test` passes.

## Implementation Status

- Phase 2 batch 1: Home, My list, and Wallet history lightweight
  loading/empty/error/retry coverage completed.
- Phase 2 batch 2: Player / For You lightweight empty/error/retry,
  unavailable episode, locked paywall, sheet/back behavior, and session
  isolation coverage completed for review.
- Phase 2 batch 3: Store / Recharge and Membership mock purchase edge
  states, disabled processing actions, close/reset behavior, package switch
  reset, and restore mock feedback coverage completed for review.
- Phase 2 batch 4: Auth / Account / Profile login edge states, login/load
  failure recovery, logout/delete failure retry, busy action disabling, and
  Profile/Auth state consistency coverage completed for review.
