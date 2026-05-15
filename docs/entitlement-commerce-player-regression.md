# Entitlement / Commerce / Player Regression Checklist

## Purpose

This checklist is for the MVP entitlement chain after E1-E3. It verifies that
Player, Store, Membership, and Wallet all read/write the shared entitlement
state instead of maintaining separate mock truth.

## Active Hotfix

真机 + Figma 深度测试发现播放器解锁链路存在 P0 音频泄漏问题，优先处理：

- 计划文档：`docs/playback-unlock-hotfix-plan.md`
- 优先级：高于多语言 Phase G
- 目标：锁定剧集 / 解锁弹窗 / 切 tab / 离开播放器时不再后台出声，并完成必要的解锁弹窗、Profile Settings、Wallet mock 默认值收口。

## Current Shared State Boundary

- `EntitlementController` is the source for membership, coin balance, auto
  unlock, unlocked episodes, and pending unlock state.
- `PlayerPage` only consumes `EpisodeAccessDecision`; `PlayerPlaybackController`
  remains free of commerce and entitlement logic.
- `StoreController` still owns recharge UI state, but mock coin purchase success
  grants coins through `EntitlementController`.
- `MembershipController` still owns membership UI state, but mock purchase
  success grants membership through `EntitlementController`.
- `WalletController` still owns wallet records and bonus display, while coins
  and auto unlock are derived from shared entitlement state.

## Manual Regression Paths

### Wallet Auto Unlock

1. Open Profile.
2. Open Wallet.
3. Toggle auto unlock.
4. Open Transaction history and return.
5. Confirm the toggle state is preserved.
6. Open a coin episode in Player:
   - enough balance + auto unlock on should deduct and play;
   - enough balance + auto unlock off should show the coin confirm sheet.

### Store Recharge

1. Open Profile or Wallet.
2. Enter Store via Top Up.
3. Buy a coin package and wait for mock success.
4. Return to Wallet.
5. Confirm the coin balance reflects shared entitlement state.
6. Open a low-balance coin episode, recharge from Player sheet, and confirm the
   pending unlock can continue.

### Membership

1. Enter Membership from Profile or Player membership CTA.
2. Buy a membership package and wait for mock success.
3. Return to Player.
4. Confirm both membership episodes and coin episodes can play for members.
5. Confirm unavailable episodes still show unavailable state for members.

### Player Unlock

1. Free episode plays directly.
2. Coin episode with low balance opens recharge sheet.
3. Coin episode with enough balance and auto unlock off opens coin confirmation.
4. Coin episode with enough balance and auto unlock on unlocks and plays.
5. Membership episode sends non-members to membership and lets members play.
6. Closing coin/recharge sheets keeps the current episode in pending unlock state.
7. Auto-next to a locked episode switches to the target episode first, then shows
   the matching unlock UI.

## Known Defer

- Profile membership card and full wallet ledger reconciliation are still not
  fully derived from server-side entitlement/order truth.
- Real payment success must wait for App Store / Google Play receipt validation
  and server entitlement refresh.
- Store, Membership, and Wallet mock data still use separate repository fixtures
  for display lists and records; only entitlement truth is shared.

## Automated Coverage Added

- Store coin purchase success updates shared entitlement balance.
- Returning to Wallet after Store top up shows the shared entitlement coin
  balance.
- Membership purchase success updates shared entitlement membership.
- Wallet auto unlock toggle writes to shared entitlement and survives history
  navigation.
