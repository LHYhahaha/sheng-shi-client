# Player Feed Engine Refactor Plan

This document records the structural refactor plan for the short-drama player
feed. The goal is to solve Android swipe jank and locked-episode flow
instability at the architecture level instead of continuing with small patches
inside `PlayerPage`.

## Why This Refactor Is Needed

The current player has already fixed several obvious issues:

- real `Video` has been moved out of PageView item shells;
- drag page offset no longer writes high-frequency state into Riverpod;
- runtime work waits for PageView settled state;
- locked episodes do not open or prepare unauthorized sources;
- previous/current/next session window already exists;
- player teardown and audio lifecycle are much safer than before.

Even with these improvements, Android device testing still reports that vertical
swiping can feel heavy, especially around locked episodes. This suggests the
remaining problem is not one missing delay or one animation value. The deeper
issue is that `PlayerPage` still acts as a page, runtime coordinator, access
coordinator, overlay coordinator, and surface coordinator at the same time.

The next phase should introduce a real feed player engine so that dragging,
playback, entitlement, overlays, and platform performance policy have clear
boundaries.

## Current Vs Target

Current implementation status:

- settled-only runtime has been partially implemented;
- real `Video` is already outside PageView item shells;
- PageView item shells are lighter than before;
- drag page offset no longer writes high-frequency Riverpod state;
- locked source open/prepare is blocked before authorization;
- several engine-like files may already exist in work-in-progress branches.

Target implementation:

- `PlayerFeedEngine` becomes the single application-layer entry point for
  viewport, access, playback, overlay, and performance policy coordination;
- Android defaults to stable mode;
- iOS can keep rich motion through policy;
- PageView drag never becomes a playback/access command bus.

Important current gap:

- The recent scroll-follow behavior is closer to rich mode. It should not be
  treated as the Android stable target.
- Android stable specifically means no real video-surface transform or opacity
  animation during drag.
- If a release package still uses scroll-follow transform on Android, Phase R6
  is not complete.

## Core Principle

During drag, the player feed must only move lightweight visual shells.

During drag, the following must not happen:

- entitlement evaluation;
- playback open/play/pause/quiesce;
- source resolve;
- HLS preload or media prepare;
- unlock/recharge sheet presentation;
- session window release;
- native video surface attach/detach.

Only after PageView settles should the final item trigger runtime work.

## Target Architecture

```text
PlayerPage
  ├─ PageView shell host
  ├─ Active video surface host
  ├─ Top bar / action rail / meta UI
  └─ Sheet host

PlayerFeedEngine
  ├─ ViewportController
  │  └─ drag / page offset / candidate index / settled item
  │
  ├─ AccessCoordinator
  │  └─ free / coin locked / recharge required / membership / unavailable
  │
  ├─ PlaybackCoordinator
  │  └─ previous retained / current playing / next prepared
  │
  ├─ OverlayCoordinator
  │  └─ Unlock Now / coin sheet / recharge sheet / dismissed state
  │
  └─ PlatformPerformancePolicy
     ├─ Android stable
     └─ iOS rich
```

`PlayerPlaybackController` should remain the media truth for actual player
state, but `PlayerPage` should no longer call it directly from scattered
listeners. Commands should go through the engine/coordinator boundary.

## Platform Policy

### Android Stable

Android stable mode prioritizes touch response over visual richness:

- no video surface transform during drag;
- no opacity animation on the real video surface;
- no press-to-dim overlay effect;
- no scale animation for transient play/pause feedback;
- PageView drags lightweight shell only;
- settled playable item attaches or switches the active video surface;
- locked/unavailable pages never mount a playable video surface.

### iOS Rich

iOS rich mode may keep richer effects where smooth:

- richer overlay transitions;
- optional video surface follow behavior;
- transient play/pause feedback;
- more polished auto-next motion.

Important: iOS and Android must share the same engine. Do not fork business
logic into two player implementations.

## Open Source References

The plan should stay custom because this product combines short-drama playback,
single-drama episode flow, entitlement, coin unlock, recharge, membership, HLS,
and platform-specific performance behavior. Still, open-source projects can be
used as architecture references.

| Reference | Type | Useful Ideas | Not A Fit For |
| --- | --- | --- | --- |
| `video_pool` | Flutter library with `media_kit` support | fixed player pool, source swap/reuse, visibility threshold, lifecycle reconciliation, memory/thermal awareness | entitlement, unlock sheets, single-drama EP business, current UI contract |
| `flutter_video_feed` | Flutter demo app | vertical feed structure, MVVM-style feed separation, LRU-style lifecycle ideas | not a drop-in package, no entitlement/payment flow |
| `tiktoklikescroller` | scroll physics package | vertical full-screen snapping and threshold behavior | playback, preload, surface lifecycle, access control |
| `progressive_video_cache` | video cache package | future HLS/segment cache ideas | drag lifecycle, PageView runtime orchestration, entitlement |
| `media_kit` examples | playback primitives | player/session/media API behavior | feed orchestration must remain app-specific |

Recommended use:

- Keep custom `ViewportController`, `AccessCoordinator`, and
  `OverlayCoordinator` because these are product-specific.
- Borrow the `video_pool` style of fixed player pool/reconcile for the playback
  coordinator, but do not replace the whole player page with a third-party feed
  widget.
- Do not adopt scroll-only packages as the main fix. They do not address
  media-session lifecycle or unlock flows.

Decision:

- Build `PlayerFeedEngine` in this codebase.
- Use `video_pool` as the closest reference for playback pooling and lifecycle
  reconciliation.
- Avoid directly introducing a third-party feed widget until the custom engine
  path is proven insufficient.

## Implementation Phases

### Phase R1a: Engine Skeleton

Goal: introduce the engine boundary without intentionally changing visuals.

Tasks:

- Add `PlayerFeedEngine` or equivalent application-layer controller.
- Move viewport settled events into the engine input.
- Keep existing UI output behavior while routing decisions through the engine.
- Define engine state fields:
  - viewport state;
  - access presentation;
  - playback command state;
  - overlay command state;
  - performance policy.

Acceptance:

- `PlayerPage` can read engine state.
- Drag still behaves as before.
- No entitlement/playback behavior change yet.

### Phase R1b: Policy Wiring

Goal: introduce policy switches without forcing all platforms into the same
motion model.

Tasks:

- Add `PlayerPerformancePolicy`.
- Android selects stable by default.
- iOS selects rich by default.
- Tests can override policy.
- Existing rich scroll-follow behavior must be guarded behind policy.

Acceptance:

- Android stable can disable rich motion without deleting rich behavior.
- iOS/rich can keep richer motion through the same engine.

### Phase R2: Runtime Commands Only After Settled

Goal: make settled item the only runtime trigger.

Tasks:

- Remove direct `feed.currentItem` runtime calls from `PlayerPage`.
- Engine consumes only final settled item.
- Drag/candidate index changes must not trigger access, playback, preload, or
  sheet work.
- Fast swipe across multiple locked items should only process the final settled
  item.

Acceptance:

- Tests prove drag does not call access evaluation.
- Tests prove drag does not call playback/preload/quiesce/release.
- Tests prove only the final settled item can trigger unlock flow.

### Phase R3: AccessCoordinator

Goal: isolate unlock entitlement decisions from the page and playback runtime.

Tasks:

- Move access presentation calculation out of `PlayerPage`.
- AccessCoordinator outputs:
  - `playable`;
  - `lockedCoins`;
  - `lockedRecharge`;
  - `lockedMembership`;
  - `unavailable`.
- AccessCoordinator must not show sheets and must not call playback.
- It should own pending unlock presentation state if needed.

Acceptance:

- PlayerPage item shell receives only an access presentation enum/model.
- Locked page UI can render without triggering playback.
- Unauthorized source is never opened, prepared, or preloaded.

### Phase R4: OverlayCoordinator

Goal: remove sheet timing and dismissal policy from `PlayerPage`.

Tasks:

- Move dwell timing, dismissed item memory, manual Unlock Now handling, and
  recharge -> coin unlock flow into OverlayCoordinator.
- Auto sheet may fire only for a settled locked item.
- Closing an auto sheet records dismissed state for that item.
- Manual `Unlock Now` bypasses dismissed auto state.

Acceptance:

- Closing sheet does not auto-reopen for the same item.
- Manual `Unlock Now` still opens immediately.
- Fast swipe cannot leave stale timers that pop sheets for old items.

### Phase R5: PlaybackCoordinator

Goal: centralize playback/preload/session-window commands.

Tasks:

- PlaybackCoordinator consumes settled access presentation.
- For `playable`: play/resume current item, then preload/prepare allowed next
  items.
- For locked/recharge/membership: quiesce or keep silent surface state without
  opening unauthorized source.
- For unavailable: block only when necessary.
- Keep previous/current/next window fixed.
- Do not expand player pool.

Acceptance:

- Free -> locked -> free swipe-back restores playback.
- Locked pages stay silent.
- Previous retained and next prepared still work.
- Hidden/tab/background still pauses and releases correctly.

### Phase R6: Android Stable Mode Enforcement

Goal: apply the performance policy consistently.

Tasks:

- Add `PlayerPerformancePolicy` provider.
- Android defaults to stable, iOS defaults to rich.
- Android stable disables:
  - press overlay dimming;
  - overlay opacity animations;
  - video surface transform/opacity animations;
  - transient scale feedback.
- Rich mode remains available through policy.

Acceptance:

- Android stable tests prove no animated opacity/transform is applied to the real
  video surface during drag.
- iOS/rich tests prove policy can keep richer behavior.

### Phase R7: Device Verification

Goal: validate the refactor on real Android hardware.

Required manual paths:

- Single drama continuous swipe: free -> free -> locked -> locked -> free.
- Close unlock sheet and keep swiping.
- Tap `Unlock Now`, close sheet, swipe again.
- Unlock by `Play`, confirm video surface resumes.
- Swipe back from locked to previous free item, confirm playback resumes.
- For You continuous 5+ swipes.
- Switch Home/My list/Profile, confirm no audio.
- App background, confirm no audio.

Metrics/logs:

- PageView item build count;
- PlayerPage build count;
- Video mount/unmount count;
- surface attach/detach count;
- session window hit/miss;
- memory/PSS before and after 10-15 swipes;
- any jank/ANR/crash.

## Implementation Status Checklist

Use this checklist to avoid repeating completed work and to make review
concrete.

| Area | Status | Notes |
| --- | --- | --- |
| Real `Video` outside PageView item shell | Mostly done | Keep tests preventing real `Video` from returning to `PlayerChrome` / item shell. |
| Drag page offset no high-frequency Riverpod write | Done | Keep page offset in lightweight listenable or viewport-local channel only. |
| Runtime waits for settled item | Partially done | Must verify no direct `currentItem` listener still triggers playback/access work. |
| Access presentation separated from UI shell | Partial | Needs a clear AccessCoordinator boundary. |
| Overlay/sheet orchestration separated | Partial | Dwell, dismissed state, manual unlock, recharge -> unlock should move out of `PlayerPage`. |
| PlaybackCoordinator separated | Partial | `PlayerPlaybackController` should stay media truth; command sequencing should move to coordinator/engine. |
| Android stable policy | Not complete | Android must disable video transform/opacity and non-essential overlay animation. |
| iOS rich policy | Not complete | Rich behavior should be policy-controlled, not implicit global behavior. |
| Open-source reference decision | Planned | Borrow `video_pool` pooling/reconcile ideas; do not replace UI wholesale. |

## Files Expected To Change

Likely new files:

- `lib/features/player/application/player_feed_engine.dart`
- `lib/features/player/application/player_access_coordinator.dart`
- `lib/features/player/application/player_overlay_coordinator.dart`
- `lib/features/player/application/player_playback_coordinator.dart`
- `lib/features/player/application/player_performance_policy.dart`

Likely modified files:

- `lib/features/player/presentation/pages/player_page.dart`
- `lib/features/player/presentation/widgets/player_chrome.dart`
- `lib/features/player/presentation/widgets/player_playback_layer.dart`
- `lib/features/player/application/player_playback_controller.dart`
- `lib/features/player/application/player_viewport_controller.dart`

Tests:

- `test/features/player/player_page_test.dart`
- `test/features/player/player_playback_controller_test.dart`
- new engine/coordinator tests under `test/features/player/`
- `integration_test/app_smoke_test.dart`
- optional Android-focused scroll stress integration test

## Explicit Constraints

- Do not change product unlock rules.
- Do not connect real API.
- Do not introduce HLS local cache/proxy.
- Do not increase prepared session window size.
- Do not mount multiple real `Video` widgets in PageView.
- Do not solve Android jank by adding arbitrary delays.
- Do not split into separate Android/iOS player codebases.

## Definition Of Done

- `PlayerPage` is mostly UI host and no longer owns runtime orchestration.
- Drag path is pure viewport movement.
- Settled item is the only runtime trigger.
- Android stable mode removes high-risk animation and video surface transforms.
- Locked flow remains correct and silent.
- Existing unit/widget tests pass.
- Android smoke passes.
- Android release manual test shows materially improved swipe responsiveness.
